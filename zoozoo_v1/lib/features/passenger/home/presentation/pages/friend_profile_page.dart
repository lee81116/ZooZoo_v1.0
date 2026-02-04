import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/glass_button.dart';

class FriendProfilePage extends StatefulWidget {
  final String name;
  final String emoji;
  final Color color;

  const FriendProfilePage({
    super.key,
    required this.name,
    required this.emoji,
    required this.color,
  });

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final List<String> _foods = ['🍖', '🍎', '🥕', '🐟', '🧀'];
  int _selectedFoodIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using withValues to avoid deprecated withOpacity if on newer Flutter,
      // or fallback to withOpacity if needed.
      // Safe option: Color.fromARGB or ensure SDK supports it.
      // Since the linter suggested .withValues(), I will use it.
      backgroundColor: widget.color.withValues(alpha: 0.9),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Top Bar with Back Button and Name
            Row(
              children: [
                const SizedBox(width: 16),
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new,
                  iconColor: Colors.white,
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(
                          right: 56), // Balance the back button spacing
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Big Avatar
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 140),
              ),
            ),

            const Spacer(),

            // Food Selector
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _foods.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedFoodIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFoodIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _foods[index],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    // Return result to indicate "Find him"
                    context.pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '叫車去找他！',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
