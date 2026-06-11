import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../screens/main_shell.dart';

/// Liquid-Glass-style material primitives (Flutter approximation).
///
/// Apple's Liquid Glass is a system-rendered material; Flutter approximates
/// the structural feel with a backdrop blur + a brightness-tinted translucent
/// fill + a hairline edge highlight. Per Apple's own guidance, glass is for
/// CHROME (bars, floating controls) — never for content surfaces that carry
/// medical text, vitals, or prices (legibility first).
/// Translucent blurred app bar. Pair with `extendBodyBehindAppBar: true` and
/// give the screen's scrollable a top padding of
/// `MediaQuery.of(context).padding.top + 8` so content glides under the glass.
///
/// NAVIGATION CONSISTENCY CONTRACT (so tabs/controls never "dance"):
///  • leading  — back button, automatic on every pushed route.
///  • trailing — [custom actions…, cart, search, home] in that fixed order.
///  • [showSearch] is on by default everywhere (universal search, top-right).
///  • [showCart] is on by default everywhere (owner: 'show cart in top
///    right'); badge shows the live item count when a CartProvider is in
///    scope. Turn OFF inside the purchase funnel (cart/checkout/payment)
///    where it would loop into itself.
///  • [showHome] is on by default for PUSHED screens AND non-Home root tabs
///    (owner: 'proper home button on every screen'); set it false only on
///    the Home tab itself.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final bool showSearch;
  final bool showCart;
  final bool showHome;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.showSearch = true,
    this.showCart = true,
    this.showHome = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: AppBar(
        title: title,
        actions: [
          ...?actions,
          if (showCart) const _CartAction(),
          if (showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => Navigator.pushNamed(context, '/search'),
            ),
          if (showHome)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
                MainShell.switchToTab(0);
              },
            ),
        ],
        automaticallyImplyLeading: automaticallyImplyLeading,
        bottom: bottom,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

/// Cart action with a live item-count badge. Degrades gracefully when no
/// CartProvider is in scope (e.g. isolated widget tests): plain icon, no
/// badge — never throws.
class _CartAction extends StatelessWidget {
  const _CartAction();

  @override
  Widget build(BuildContext context) {
    int count = 0;
    try {
      count = Provider.of<CartProvider>(context).itemCount;
    } catch (_) {
      // No CartProvider above this bar — badge-less icon.
    }
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => Navigator.pushNamed(context, '/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  /// Blur strength. ~24 reads as "regular" glass; keep consistent app-wide.
  final double sigma;

  /// Fill opacity over the blur. Higher = more legible, less glassy.
  /// 0.55 lets scrolling content visibly bleed through the material —
  /// frosted glass over a white page is invisible at higher fills.
  final double opacity;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.sigma = 24,
    this.opacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Dark fill matches the calm-pass card family (#1C1C1E on true black).
    final fill = dark
        ? const Color(0xFF1C1C1E).withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity);
    // Top edge highlight sells the "pane of glass" read.
    final edge = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: borderRadius != null
                ? Border.all(color: edge, width: 0.5)
                : Border(top: BorderSide(color: edge, width: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}
