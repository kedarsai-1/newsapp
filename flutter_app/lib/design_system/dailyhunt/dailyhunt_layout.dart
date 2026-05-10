import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// Responsive layout helpers + spacing aliases (8pt grid via [AppSpacing]).
class DhLayout {
  DhLayout._();

  static const double maxContentWidth = 720;
  static const double wideBreakpoint = 900;
  static const double mediumBreakpoint = 600;

  static double pageHorizontalPadding(double width) =>
      width >= wideBreakpoint ? 24.0 : (width >= mediumBreakpoint ? 20.0 : 14.0);

  static EdgeInsets pageInsets(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = pageHorizontalPadding(w);
    return EdgeInsets.fromLTRB(h, AppSpacing.s12, h, AppSpacing.s16);
  }

  /// Wraps [child] with centered max width for tablet/desktop readability.
  static Widget constrainedBody({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
