import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Vehicle selection bottom sheet
class VehicleSelectionSheet extends StatefulWidget {
  final String destination;
  final Function(String vehicleType, int price) onConfirm;

  const VehicleSelectionSheet({
    super.key,
    required this.destination,
    required this.onConfirm,
  });

  @override
  State<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends State<VehicleSelectionSheet> {
  int _selectedIndex = 0;

  final List<_VehicleType> _vehicleTypes = [
    _VehicleType(
      name: '元氣汪汪',
      description: '標準舒適',
      price: 85,
      eta: 3,
      imagePath: 'assets/images/vehicles/dog.png',
    ),
    _VehicleType(
      name: '招財貓貓',
      description: '寬敞舒適',
      price: 120,
      eta: 5,
      imagePath: 'assets/images/vehicles/neko.png',
    ),
    _VehicleType(
      name: '北極熊阿北',
      description: '大型車輛',
      price: 150,
      eta: 8,
      imagePath: 'assets/images/vehicles/bear.png',
    ),
    _VehicleType(
      name: '袋鼠媽媽',
      description: '親子座椅',
      price: 130,
      eta: 6,
      imagePath: 'assets/images/vehicles/kangaroo.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = _vehicleTypes[_selectedIndex];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '選擇車型',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.destination,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Vehicle list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _vehicleTypes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vehicle = _vehicleTypes[index];
                final isSelected = index == _selectedIndex;
                return _buildVehicleCard(vehicle, isSelected, index);
              },
            ),
          ),
          const SizedBox(height: 16),
          // ETA display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '預估 ${selectedVehicle.eta} 分鐘後到達',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(
                    selectedVehicle.name,
                    selectedVehicle.price,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '確認叫車 · \$${selectedVehicle.price}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(_VehicleType vehicle, bool isSelected, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Price (left)
            SizedBox(
              width: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${vehicle.price}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.accent,
                    ),
                  ),
                  Text(
                    '${vehicle.eta}分鐘',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? AppColors.primary : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            // Info (center)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Symbol (right) - transparent background for PNG
            SizedBox(
              width: 56,
              height: 56,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  vehicle.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.directions_car,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleType {
  final String name;
  final String description;
  final int price;
  final int eta; // minutes
  final String imagePath;

  _VehicleType({
    required this.name,
    required this.description,
    required this.price,
    required this.eta,
    required this.imagePath,
  });
}
