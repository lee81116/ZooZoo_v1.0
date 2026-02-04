import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/widgets/glass_button.dart';

class PersonalProfilePage extends StatefulWidget {
  const PersonalProfilePage({super.key});

  @override
  State<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends State<PersonalProfilePage> {
  final List<String> _foods = ['🍖', '🍎', '🥕', '🐟', '🧀'];
  int _selectedFoodIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Determine background color based on "Self" theme (e.g. Brown/Orange from sketch)
    final themeColor = const Color(0xFFC08A70); // Muted earthy tone from sketch

    return Scaffold(
      backgroundColor: themeColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Column(
              children: [
                const Spacer(flex: 2),

                // Big Avatar (Self)
                Container(
                  width: 300,
                  height: 480,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD06040),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person,
                    size: 150,
                    color: Colors.white,
                  ),
                ),

                const Spacer(flex: 1),

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
                                ? const Color(0xFF6B4B3E)
                                : Colors.black.withValues(alpha: 0.2),
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

                const SizedBox(height: 40),

                // Bottom Row (Store, Character, Almanac)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMenuButton(Icons.store, "商店"),
                      _buildMenuButton(Icons.pets, "角色"),
                      _buildMenuButton(Icons.menu_book, "圖鑑"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),

            // Back Button (Floating Top Left)
            Positioned(
              top: 10,
              left: 16,
              child: GlassIconButton(
                icon: Icons.arrow_back_ios_new,
                iconColor: Colors.white,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, String label) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF4A3B32), // Dark Brown
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          // const SizedBox(height: 4),
          // Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
