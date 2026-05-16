import 'package:flutter/material.dart';

/// Exposes the user-shell drawer opener to nested routes (feed, shorts, etc.).
class XpressoMenuScope extends InheritedWidget {
  final VoidCallback openMenu;

  const XpressoMenuScope({
    super.key,
    required this.openMenu,
    required super.child,
  });

  static XpressoMenuScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<XpressoMenuScope>();
  }

  static void open(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null) {
      scope.openMenu();
      return;
    }
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.hasDrawer == true) {
      scaffold!.openDrawer();
    }
  }

  @override
  bool updateShouldNotify(XpressoMenuScope oldWidget) =>
      oldWidget.openMenu != openMenu;
}
