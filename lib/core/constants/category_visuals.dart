import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';

/// Fixed 16-swatch colour palette for category `colour_hex` (spec §11.5) —
/// deliberately small and closed so every device renders the same set of
/// choices, and so hex values stay predictable for the icon/colour picker.
///
/// Palette upgraded to vibrant neon-friendly tones.
const List<String> categoryColourPalette = [
  '#FF6B6B', // coral red
  '#F06292', // soft pink
  '#BA68C8', // purple orchid
  '#7E57C2', // deep purple
  '#5C6BC0', // indigo
  '#42A5F5', // bright blue
  '#29B6F6', // sky blue
  '#26C6DA', // cyan
  '#26A69A', // teal
  '#66BB6A', // green
  '#9CCC65', // light green
  '#D4E157', // lime
  '#FFCA28', // amber
  '#FFA726', // orange
  '#8D6E63', // warm brown
  '#78909C', // blue grey
];

Color colourFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

/// Fixed set of ~40 Material icon keys for category `icon_key` (spec §11.5).
/// The key (not the [IconData]) is what's persisted, so this map is the only
/// place allowed to change which icon a key renders as.
///
/// All icons use the `_rounded` variant for a modern, softer look.
const Map<String, IconData> categoryIconOptions = {
  'category': Icons.category_rounded,
  'restaurant': Icons.restaurant_rounded,
  'local_cafe': Icons.local_cafe_rounded,
  'local_grocery_store': Icons.local_grocery_store_rounded,
  'shopping_cart': Icons.shopping_cart_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'directions_car': Icons.directions_car_rounded,
  'local_gas_station': Icons.local_gas_station_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'flight': Icons.flight_rounded,
  'home': Icons.home_rounded,
  'bolt': Icons.bolt_rounded,
  'water_drop': Icons.water_drop_rounded,
  'wifi': Icons.wifi_rounded,
  'phone_android': Icons.phone_android_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'medication': Icons.medication_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'school': Icons.school_rounded,
  'menu_book': Icons.menu_book_rounded,
  'movie': Icons.movie_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'music_note': Icons.music_note_rounded,
  'checkroom': Icons.checkroom_rounded,
  'spa': Icons.spa_rounded,
  'pets': Icons.pets_rounded,
  'child_care': Icons.child_care_rounded,
  'card_giftcard': Icons.card_giftcard_rounded,
  'celebration': Icons.celebration_rounded,
  'favorite': Icons.favorite_rounded,
  'volunteer_activism': Icons.volunteer_activism_rounded,
  'build': Icons.build_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  'local_laundry_service': Icons.local_laundry_service_rounded,
  'savings': Icons.savings_rounded,
  'account_balance': Icons.account_balance_rounded,
  'receipt_long': Icons.receipt_long_rounded,
  'work': Icons.work_rounded,
  'laptop': Icons.laptop_rounded,
  'more_horiz': Icons.more_horiz_rounded,
};

IconData iconForKey(String key) =>
    categoryIconOptions[key] ?? categoryIconOptions['category']!;

/// Payment methods have no user-chosen icon — their `type` enum maps to a
/// fixed icon (spec §11.5 only describes icon/colour pickers for
/// categories; `payment_method` has no `icon_key`/`colour_hex` column).
IconData iconForPaymentMethodType(PayMethodType type) => switch (type) {
  PayMethodType.cash => Icons.payments_rounded,
  PayMethodType.upi => Icons.qr_code_scanner_rounded,
  PayMethodType.card => Icons.credit_card_rounded,
  PayMethodType.bank => Icons.account_balance_rounded,
  PayMethodType.wallet => Icons.account_balance_wallet_rounded,
  PayMethodType.other => Icons.more_horiz_rounded,
};
