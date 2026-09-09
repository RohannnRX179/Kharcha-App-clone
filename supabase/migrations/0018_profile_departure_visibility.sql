-- Fixes a real, live-found gap in departure visibility (found testing
-- Gate 14's Remove-member item, 2026-09-09): a member who leaves
-- (leave_household) or is removed (remove_member) with ZERO transaction
-- history in that household becomes permanently invisible to former
-- housemates' RLS. profile_visible_to_me()'s only branches beyond "it's
-- your own row" require either a still-matching household_id (which
-- leaving/removal deliberately nulls out — the person might join a
-- different household later) or an expense/income they authored there.
-- A member with neither — a real, plausible case, not just a test
-- artifact — leaves nothing for incremental selectSince(cursor) to ever
-- pull: their now-household_id=null row simply never reaches other
-- devices, so an already-cached "still a member" copy can never
-- self-correct except via a full "Clear cache and re-download" (which
-- works only because a fresh RLS-scoped pull naturally excludes what it
-- can no longer see — confirmed live against real production data,
-- removing a real household member, see docs/DECISIONS.md).
--
-- Fix: profiles gains `last_departed_household_id`, stamped alongside
-- the existing household_id=null on both leave and remove.
-- profile_visible_to_me() gains a branch matching on it. This makes the
-- row pullable by former housemates at least once after departure — the
-- client needs no changes at all, since it already correctly reacts to
-- a household_id=null profile row (the exact mechanism that already
-- works when the departed member DID leave a transaction behind, e.g.
-- Rupesh's 2026-09-07 departure): ProfileSyncAdapter.selectSince()
-- already passes filterByHousehold: false and relies entirely on RLS,
-- and the Household screen's own watchAll() already filters by a
-- matching household_id, so a correctly-nulled local row is
-- automatically excluded from the roster the moment it's pulled.

alter table public.profiles add column last_departed_household_id uuid;

create or replace function public.profile_visible_to_me(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_profile = auth.uid()
      or exists (select 1 from public.profiles pr
                  where pr.id = p_profile
                    and pr.household_id is not null
                    and pr.household_id = public.current_household_id())
      or exists (select 1 from public.profiles pr
                  where pr.id = p_profile
                    and pr.last_departed_household_id = public.current_household_id())
      or exists (select 1 from public.expenses e
                  where e.user_id = p_profile
                    and e.household_id = public.current_household_id())
      or exists (select 1 from public.incomes i
                  where i.user_id = p_profile
                    and i.household_id = public.current_household_id());
$$;

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
         last_departed_household_id = v_hh,
         updated_at = now(), client_edited_at = now()
   where id = v_uid;
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
         last_departed_household_id = v_hh,
         updated_at = now(), client_edited_at = now()
   where id = p_user;
end;
$$;
