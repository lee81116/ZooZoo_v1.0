import 'package:flutter/material.dart';

import '../../../../../core/services/map/map_models.dart';
import '../../../../../core/theme/app_colors.dart';

/// Saved places list widget
class SavedPlacesList extends StatelessWidget {
  final Function(AppLatLng latLng, String name) onPlaceSelected;

  const SavedPlacesList({
    super.key,
    required this.onPlaceSelected,
  });

  // Mock saved places
  List<_SavedPlace> get _savedPlaces => [
    _SavedPlace(
      '家',
      '台北市大安區忠孝東路四段',
      Icons.home_rounded,
      const AppLatLng(25.0418, 121.5445),
    ),
    _SavedPlace(
      '公司',
      '台北市信義區松仁路100號',
      Icons.business_rounded,
      const AppLatLng(25.0330, 121.5680),
    ),
    _SavedPlace(
      '收藏地點',
      '查看所有收藏',
      Icons.star_rounded,
      null, // Opens saved list
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '常用地點',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _savedPlaces.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final place = _savedPlaces[index];
              return _buildPlaceCard(context, place);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(BuildContext context, _SavedPlace place) {
    return GestureDetector(
      onTap: () {
        if (place.latLng != null) {
          onPlaceSelected(place.latLng!, place.name);
        } else {
          // Show all saved places
          _showAllSavedPlaces(context);
        }
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                place.icon,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const Spacer(),
            Text(
              place.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              place.subtitle,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAllSavedPlaces(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '收藏地點',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            const Text(
              '尚無收藏地點',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SavedPlace {
  final String name;
  final String subtitle;
  final IconData icon;
  final AppLatLng? latLng;

  _SavedPlace(this.name, this.subtitle, this.icon, this.latLng);
}
