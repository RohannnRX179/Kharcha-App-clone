-- Fixes the "deleted-account profile cache gap" (docs/DECISIONS.md,
-- 2026-09-09, found live testing F-18 right after Gate M2's join-by-code
-- pass): profiles.id had `references auth.users(id) on delete cascade`, so
-- the account-deletion Edge Function's final step (admin.auth.admin.
-- deleteUser) hard-deleted the profile row in the same instant. A hard
-- delete leaves incremental sync with nothing to detect — PullService's
-- selectSince(cursor) only sees rows whose updated_at moved past the
-- cursor, and a row that no longer exists produces no row at all — so
-- every other member's device kept the deleted person in its cached
-- roster indefinitely, until someone happened to run a full "Clear cache
-- and re-download".
--
-- Fix: profiles now survives its own auth.users row's deletion — the
-- cascading FK is dropped, so the identity record intentionally outlives
-- the auth account, exactly the way a departed member's row already
-- outlives their household membership (see "Profiles-tombstone gap",
-- 2026-09-07) — and delete_my_records() marks it deleted_at instead of
-- relying on the cascade. household_id is deliberately left untouched
-- (unlike leave_household()'s null-out) so profile_visible_to_me()'s
-- existing "current member of your household" branch keeps the tombstone
-- visible to former housemates — exactly the signal their next pull needs
-- to hard-delete their own stale local copy (entity_sync_adapters.dart's
-- ProfileSyncAdapter.pullApply, mirroring every other tombstoned entity).
--
-- Every RPC that counts household members/admins by household_id, and the
-- Edge Function's own membership lookup, must now exclude deleted_at rows
-- — before this migration a deleted profile could never linger with a
-- live household_id (the cascade removed it outright), so none of those
-- counts needed to filter it out. Left unfiltered, a household with one
-- real remaining admin plus N tombstoned former members would
-- mis-evaluate "last admin"/"household not empty" checks.

alter table public.profiles add column deleted_at timestamptz;

-- Drop the FK by introspection rather than a guessed constraint name, so
-- this migration doesn't silently no-op against the real production
-- constraint name if it ever differs from Postgres's default convention.
do $$
declare v_conname text;
begin
  select conname into v_conname
    from pg_constraint
   where conrelid = 'public.profiles'::regclass
     and contype = 'f'
     and confrelid = 'auth.users'::regclass;
  if v_conname is not null then
    execute format('alter table public.profiles drop constraint %I', v_conname);
  end if;
end $$;

-- Tombstones the caller's own profile row (see header) instead of the old
-- cascade. Byte-identical to 0015's version otherwise.
create or replace function public.delete_my_records()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_e int; v_i int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  delete from public.attachments a
   where a.expense_id in (select id from public.expenses where user_id = v_uid);
  with d as (delete from public.expenses where user_id = v_uid returning 1)
    select count(*) into v_e from d;
  with d as (delete from public.incomes  where user_id = v_uid returning 1)
    select count(*) into v_i from d;
  delete from public.budgets        where user_id = v_uid;
  delete from public.recurring_rules where user_id = v_uid;

  update public.profiles
     set deleted_at = now(), is_active = false
   where id = v_uid;

  return jsonb_build_object('expenses_deleted', v_e, 'incomes_deleted', v_i);
end;
$$;

-- Only the household_id/deleted_at filters changed from 0015's version —
-- a tombstoned former member must not count toward "household not empty".
create or replace function public.delete_household()
returns void language plpgsql security definer set search_path = public as $$
declare v_hh uuid := public.current_household_id();
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if v_hh is null then raise exception 'not_in_household'; end if;
  if (select count(*) from public.profiles
       where household_id = v_hh and deleted_at is null) > 1 then
    raise exception 'household_not_empty';
  end if;

  perform set_config('kharcha.allow_membership_change', 'on', true);
  update public.profiles
     set household_id = null, role = 'member', joined_at = null
   where household_id = v_hh and deleted_at is null;

  delete from public.households where id = v_hh;
end;
$$;

-- Only the "last_admin" count and the target-membership lookup gained
-- `deleted_at is null` — everything else is byte-identical to 0016's
-- version.
create or replace function public.leave_household()
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_hh uuid; v_role public.member_role;
begin
  select household_id, role into v_hh, v_role from public.profiles where id = v_uid;
  if v_hh is null then raise exception 'not_in_household'; end if;

  if v_role = 'admin'
     and (select count(*) from public.profiles
           where household_id = v_hh and role = 'admin' and deleted_at is null) = 1
     and (select count(*) from public.profiles
           where household_id = v_hh and deleted_at is null) > 1 then
    raise exception 'last_admin';
  end if;

  perform set_config('kharcha.allow_membership_change', 'on', true);
  update public.profiles
     set household_id = null, role = 'member', joined_at = null,
         updated_at = now(), client_edited_at = now()
   where id = v_uid;
end;
$$;

create or replace function public.set_member_role(p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare v_hh uuid := public.current_household_id();
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if p_role not in ('admin','member') then raise exception 'bad_role'; end if;
  if v_hh is null then raise exception 'not_in_household'; end if;
  if (select household_id from public.profiles
       where id = p_user and deleted_at is null) is distinct from v_hh then
    raise exception 'not_a_member';
  end if;

  if p_role = 'member'
     and (select count(*) from public.profiles
           where household_id = v_hh and role = 'admin' and deleted_at is null) = 1
     and (select role from public.profiles where id = p_user) = 'admin' then
    raise exception 'last_admin';
  end if;

  perform set_config('kharcha.allow_membership_change', 'on', true);
  update public.profiles
     set role = p_role::public.member_role, updated_at = now(), client_edited_at = now()
   where id = p_user;
end;
$$;

create or replace function public.set_member_active(p_user uuid, p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_hh uuid := public.current_household_id();
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if (select household_id from public.profiles
       where id = p_user and deleted_at is null) is distinct from v_hh then
    raise exception 'not_a_member';
  end if;
  if p_user = auth.uid() then raise exception 'cannot_deactivate_self'; end if;
  update public.profiles
     set is_active = p_active, updated_at = now(), client_edited_at = now()
   where id = p_user;
end;
$$;

create or replace function public.remove_member(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_hh uuid := public.current_household_id();
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if p_user = auth.uid() then raise exception 'use_leave_household'; end if;
  if (select household_id from public.profiles
       where id = p_user and deleted_at is null) is distinct from v_hh then
    raise exception 'not_a_member';
  end if;

  perform set_config('kharcha.allow_membership_change', 'on', true);
  update public.profiles
     set household_id = null, role = 'member', joined_at = null,
         updated_at = now(), client_edited_at = now()
   where id = p_user;
end;
$$;
