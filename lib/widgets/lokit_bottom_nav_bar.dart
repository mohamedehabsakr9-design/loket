import 'package:flutter/material.dart';

enum LokitBottomTab {
  home,
  search,
  wishlist,
  cart,
  profile,
}

class LokitBottomNavBar extends StatelessWidget {
  final LokitBottomTab currentTab;

  const LokitBottomNavBar({
    super.key,
    required this.currentTab,
  });

  static const Color _dark = Color(0xFF1D282E);
  static const Color _inactive = Color(0xFF5F6668);
  static const Color _barColor = Color(0xFFF1F1F1);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _barColor,
          borderRadius: BorderRadius.circular(38),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: currentTab == LokitBottomTab.home,
              onTap: () => _goTo(context, LokitBottomTab.home),
            ),
            _NavItem(
              icon: Icons.search_rounded,
              label: 'Search',
              isActive: currentTab == LokitBottomTab.search,
              onTap: () => _goTo(context, LokitBottomTab.search),
            ),
            _NavItem(
              icon: currentTab == LokitBottomTab.wishlist
                  ? Icons.favorite_rounded
                  : Icons.favorite_rounded,
              label: 'Wishlist',
              isActive: currentTab == LokitBottomTab.wishlist,
              onTap: () => _goTo(context, LokitBottomTab.wishlist),
            ),
            _NavItem(
              icon: Icons.shopping_cart_rounded,
              label: 'Cart',
              isActive: currentTab == LokitBottomTab.cart,
              onTap: () => _goTo(context, LokitBottomTab.cart),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isActive: currentTab == LokitBottomTab.profile,
              onTap: () => _goTo(context, LokitBottomTab.profile),
            ),
          ],
        ),
      ),
    );
  }

  void _goTo(BuildContext context, LokitBottomTab tab) {
    if (tab == currentTab) return;

    final route = switch (tab) {
      LokitBottomTab.home => '/home',
      LokitBottomTab.search => '/search',
      LokitBottomTab.wishlist => '/wishlist',
      LokitBottomTab.cart => '/cart',
      LokitBottomTab.profile => '/profile',
    };

    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (route) => false,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  static const Color _dark = Color(0xFF1D282E);
  static const Color _inactive = Color(0xFF5F6668);

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: _dark,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _dark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 42,
        child: Icon(
          icon,
          color: _inactive,
          size: 25,
        ),
      ),
    );
  }
}