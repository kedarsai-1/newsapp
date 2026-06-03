import 'package:flutter/material.dart';
import 'glass_background.dart';
// import 'glass_app_bar.dart'; // removed - not needed

/// A Scaffold wrapper that provides a glass‑morphism background.
///
/// Use this widget in place of the regular `Scaffold` to get the premium
/// blurred background and optionally a [GlassAppBar].
class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? child;
  final Widget? floatingActionButton;
  final List<Widget>? persistentFooterButtons;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  final bool safeArea;
  const GlassScaffold({
    Key? key,
    this.appBar,
    this.child,
    this.floatingActionButton,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.safeArea = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If a custom appBar is supplied, we keep it; otherwise we can use a
    // default GlassAppBar if needed by the caller.
    final Widget? effectiveAppBar = appBar;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: backgroundColor ?? Colors.transparent,
        appBar: effectiveAppBar as PreferredSizeWidget?,
        body: safeArea && child != null ? SafeArea(child: child!) : (child ?? const SizedBox.shrink()),
        floatingActionButton: floatingActionButton,
        persistentFooterButtons: persistentFooterButtons,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
