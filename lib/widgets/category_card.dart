import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;

  const CategoryCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(
                  (0.7 * 255).round(),
                  color.r.toInt(),
                  color.g.toInt(),
                  color.b.toInt(),
                ),
                color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // 배경 장식
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white.withAlpha(50),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (isLocked)
                          const Icon(
                            Icons.lock,
                            color: Colors.white,
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withAlpha(204), // 0.8 * 255
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 잠금 오버레이
              if (isLocked)
                Container(
                  color: Colors.black.withAlpha(102), // 0.4 * 255
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 