import 'package:json_annotation/json_annotation.dart';

/// Mirrors the Postgres enums in `0001_extensions.sql` exactly.

enum MemberRole { admin, member }

enum CategoryKind { expense, income }

enum PayMethodType { cash, upi, card, bank, wallet, other }

enum BudgetScope {
  household,
  user,
  category,
  @JsonValue('user_category')
  userCategory,
}

enum RecurFrequency { daily, weekly, monthly, yearly }

enum TxnKind { expense, income }

/// Mirrors `feedback.category`'s check constraint (`0011_multitenant_core.sql`,
/// spec F-17) — every value's `.name` is already the exact db string.
enum FeedbackCategory { general, bug, idea, confusing, praise }
