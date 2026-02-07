import 'dart:async';
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

  // Options state
  final List<String> _options = ['一般模式', '幫我趕一下', '舒適模式', '安靜模式'];
  Set<String> _selectedOptions = {'一般模式'};
  bool _showConflictToast = false;
  Timer? _toastTimer;

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
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _handleOptionTap(String option) {
    if (option == '幫我趕一下') {
      // Logic update: Selecting "Hurry Up" overrides "Comfort"
      setState(() {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
          // Fallback to General if no specific mode left
          if (!_selectedOptions.contains('舒適模式')) {
            _selectedOptions.add('一般模式');
          }
        } else {
          _selectedOptions.add(option);
          _selectedOptions.remove('一般模式');
          _selectedOptions.remove('舒適模式'); // Auto-uncheck Comfort
        }
      });
    } else if (option == '舒適模式') {
      if (_selectedOptions.contains('幫我趕一下')) {
        _showToast();
        return;
      }
      setState(() {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
          if (!_selectedOptions.contains('幫我趕一下')) {
            _selectedOptions.add('一般模式');
          }
        } else {
          _selectedOptions.add(option);
          _selectedOptions.remove('一般模式');
        }
      });
    } else if (option == '一般模式') {
      setState(() {
        _selectedOptions.add('一般模式');
        _selectedOptions.remove('幫我趕一下');
        _selectedOptions.remove('舒適模式');
      });
    } else if (option == '安靜模式') {
      setState(() {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
        } else {
          _selectedOptions.add(option);
        }
      });
    }
  }

  void _showToast() {
    setState(() {
      _showConflictToast = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showConflictToast = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = _vehicleTypes[_selectedIndex];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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

          // Dark Coffee Block Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Conflict Toast
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showConflictToast ? 1.0 : 0.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '趕時間時無法選擇舒適模式',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Options Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _options.map((option) {
                      final isSelected = _selectedOptions.contains(option);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _handleOptionTap(option),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE0E0E0)
                                  : Colors.white, // Selected is darker
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.check,
                                        size: 16, color: Colors.black),
                                  ),
                                Text(
                                  option,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Confirm button
                SizedBox(
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
              ],
            ),
          ),
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
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
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
                      color:
                          isSelected ? AppColors.primary : AppColors.textHint,
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
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
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
