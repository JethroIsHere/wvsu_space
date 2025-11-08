import 'package:flutter/material.dart';
import '../router/app_router.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onIndexChanged;

  const BottomNav({required this.currentIndex, this.onIndexChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.chat_bubble,
                label: 'Chat',
                selected: currentIndex == 0,
                selectedColor: colorScheme.primary,
                onTap: onIndexChanged != null
                    ? () => onIndexChanged!(0)
                    : () => Navigator.pushNamed(context, AppRouter.home),
              ),
              _NavItem(
                icon: Icons.forum_outlined,
                label: 'Rooms',
                selected: currentIndex == 1,
                selectedColor: colorScheme.primary,
                onTap: onIndexChanged != null ? () => onIndexChanged!(1) : null,
              ),
              _NavItem(
                icon: Icons.favorite_border,
                label: 'Gratitude',
                selected: currentIndex == 2,
                selectedColor: colorScheme.primary,
                onTap: onIndexChanged != null ? () => onIndexChanged!(2) : null,
              ),
              _NavItem(
                icon: Icons.leaderboard_outlined,
                label: 'Standing',
                selected: currentIndex == 3,
                selectedColor: colorScheme.primary,
                onTap: onIndexChanged != null
                    ? () => onIndexChanged!(3)
                    : () => Navigator.pushNamed(
                        context,
                        AppRouter.communityStanding,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            begin: Colors.black54,
            end: selected ? Colors.white : Colors.black54,
          ),
          duration: const Duration(milliseconds: 220),
          builder: (context, color, _) => Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
          ),
          child: Text(label),
        ),
      ],
    );

    final widget = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      padding: selected
          ? const EdgeInsets.symmetric(vertical: 6, horizontal: 14)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: selected
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: base,
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: widget,
    );
  }
}
