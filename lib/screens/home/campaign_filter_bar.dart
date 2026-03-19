// ═══════════════════════════════════════════════════════════════════════════
// PRIORITY 4 — App Icon config
// Add this block to pubspec.yaml (top-level, same indent as "flutter:")
// Then run: dart run flutter_launcher_icons
// ═══════════════════════════════════════════════════════════════════════════

/*
Add to pubspec.yaml dev_dependencies:
  flutter_launcher_icons: ^0.14.1

Add this TOP-LEVEL block (same level as "flutter:", not nested inside it):

flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  remove_alpha_ios: true
  image_path: "assets/image.asset.png"
  min_sdk_android: 21
  adaptive_icon_background: "#1B2263"
  adaptive_icon_foreground: "assets/image.asset.png"
  web:
    generate: true
    image_path: "assets/image.asset.png"
    background_color: "#1B2263"
    theme_color: "#F5A800"

Then run in terminal:
  dart run flutter_launcher_icons
*/

// ═══════════════════════════════════════════════════════════════════════════
// PRIORITY 5 — Campaign Filter Clear Button
// Drop the _FilterBar widget below into home_screen.dart
// and replace the existing filter chip row with it.
// ═══════════════════════════════════════════════════════════════════════════

// lib/screens/home/home_screen.dart  — ADD these two widget classes:

import 'package:flutter/material.dart';

const _navy = Color(0xFF1B2263);
const _gold = Color(0xFFF5A800);

// ─── Filter bar with clear button ────────────────────────────────────────────
// Usage — replace existing chip row with:
//
//   _FilterBar(
//     categories:       ['All', ...categories],
//     selectedCategory: _selectedCategory,
//     searchText:       _searchController.text,
//     priceFilter:      _priceFilter,
//     onCategoryChanged: (cat) {
//       setState(() => _selectedCategory = cat);
//       context.read<CampaignProvider>().filterByCategory(cat);
//     },
//     onClearAll: _clearAllFilters,
//   )
//
// Add to your state:
//   void _clearAllFilters() {
//     setState(() {
//       _selectedCategory = 'All';
//       _priceFilter      = null;
//     });
//     _searchController.clear();
//     context.read<CampaignProvider>().filterByCategory('All');
//   }

class CampaignFilterBar extends StatelessWidget {
  final List<String>       categories;
  final String             selectedCategory;
  final String             searchText;
  final double?            priceFilter;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback         onClearAll;

  const CampaignFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.searchText,
    required this.priceFilter,
    required this.onCategoryChanged,
    required this.onClearAll,
  });

  bool get _hasActiveFilter =>
      selectedCategory != 'All' ||
          searchText.isNotEmpty ||
          priceFilter != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + (_hasActiveFilter ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // "Clear all" chip is always first when any filter is active
          if (_hasActiveFilter && index == 0) {
            return _ClearAllChip(onTap: onClearAll);
          }

          final catIndex = _hasActiveFilter ? index - 1 : index;
          final cat      = categories[catIndex];
          final selected = cat == selectedCategory;

          return ChoiceChip(
            label: Text(cat,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color:
                    selected ? Colors.white : _navy)),
            selected: selected,
            onSelected: (_) => onCategoryChanged(cat),
            selectedColor: _navy,
            backgroundColor: Colors.white,
            side: BorderSide(
                color: selected
                    ? _navy
                    : Colors.grey.shade300,
                width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 0),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _ClearAllChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearAllChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
              color: Colors.red.shade400, width: 1.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.close,
              size: 14, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Text('Clear all',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}