import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/reporter_provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/app_utils.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../widgets/profile/dailyhunt_settings_section.dart';

/// Reporter workspace settings — account essentials only (no consumer feed prefs).
class ReporterProfileScreen extends StatelessWidget {
  const ReporterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final fx = FeedXpressoTheme.fx(context);
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        XpressoSliverAppBar(title: I18n.t(context, 'tab_settings')),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (user != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: fx.iconSurface,
                        child: Text(
                          AppUtils.initials(user.name),
                          style: TextStyle(
                            color: fx.title,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: fx.title,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(fontSize: 12, color: fx.summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DailyhuntSettingsSection(
                  title: I18n.t(context, 'section_account'),
                  child: XpressoSettingsRow(
                    icon: Icons.badge_outlined,
                    title: I18n.t(context, 'tile_reporter_role'),
                    subtitle: I18n.t(context, 'tile_reporter_role_sub'),
                  ),
                ),
              ],
              SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    await auth.logout();
                    context.read<ReporterProvider>().reset();
                    if (!context.mounted) return;
                    context.go('/login');
                  },
                  icon: Icon(Icons.logout_rounded, size: 18, color: fx.iconFg),
                  label: Text(
                    I18n.t(context, 'action_signout'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: fx.summary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
