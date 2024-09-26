import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inno_ft/components/theme_provider.dart';

class ThemeToggleSwitch extends ConsumerStatefulWidget {
  @override
  _ThemeToggleSwitchState createState() => _ThemeToggleSwitchState();
}

class _ThemeToggleSwitchState extends ConsumerState<ThemeToggleSwitch> {
  bool _isExpanded = false; // Track whether the theme toggle is expanded

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = ref.watch(themeNotifierProvider); // Watch for theme changes

    return Stack(
      children: [
        // Sliding theme switch container
        AnimatedPositioned(
          duration: Duration(milliseconds: 300),
          left: _isExpanded ? 0 : -160, // Slide most of the container offscreen but leave the arrow visible
          top: MediaQuery.of(context).size.height / 2 - 50, // Center vertically
          child: Container(
            width: 200, // Fixed width for the container
            padding: EdgeInsets.all(8.0), // Add padding for better appearance
            decoration: BoxDecoration(
              color: Colors.white, // Background color for better visibility
              borderRadius: BorderRadius.circular(10), // Rounded corners
              boxShadow: [
                BoxShadow(
                  color: Colors.black12, // Add a shadow for better visibility
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Arrow to indicate toggle action positioned on the right side of the panel
                Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Align arrow to the right
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded; // Toggle the expansion only when arrow is clicked
                        });
                      },
                      child: Icon(
                        _isExpanded
                            ? Icons.arrow_back_ios
                            : Icons.arrow_forward_ios, // Arrow icon
                        size: 16,
                      ),
                    ),
                  ],
                ),
                // Switch to toggle theme (Doesn't collapse the panel on interaction)
                Switch(
                  value: isDarkTheme,
                  onChanged: (value) {
                    ref.read(themeNotifierProvider.notifier).toggleTheme(); // Toggle theme
                  },
                ),
              ],
            ),
          ),
        ),

        // Detect clicks outside the theme toggle to close it
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _isExpanded = false; // Collapse when clicking outside the box
                });
              },
            ),
          ),
      ],
    );
  }
}