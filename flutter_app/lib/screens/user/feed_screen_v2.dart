import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Enhanced FeedScreen with Way2News-style horizontal scrolling
/// This shows how to replace the existing FeedScreen
class FeedScreenV2 extends StatefulWidget {
  const FeedScreenV2({super.key});

  @override
  State<FeedScreenV2> createState() => _FeedScreenV2State();
}

class _FeedScreenV2State extends State<FeedScreenV2>
    with AutomaticKeepAliveClientMixin {
  late final ValueNotifier<bool> _modeNotifier;
  bool _showWay2NewsMode = false;

  @override
  void initState() {
    super.initState();
    _modeNotifier = ValueNotifier(false);
    _checkModePreference();
  }

  @override
  void dispose() {
    _modeNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkModePreference() async {
    // Check if user has a preference stored
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('feed_view_mode');
    setState(() {
      _showWay2NewsMode = savedMode == 'way2news';
    });
  }

  Future<void> _setFeedMode(bool isWay2News) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feed_view_mode', isWay2News ? 'way2news' : 'classic');
    setState(() {
      _showWay2NewsMode = isWay2News;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: FeedXpressoTheme.fx(context).background,
      body: ValueListenableBuilder<bool>(
        valueListenable: _modeNotifier,
        builder: (context, _, child) {
          if (_showWay2NewsMode) {
            return const Way2NewsFeedScreen();
          }
          return const ClassicFeedScreen();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _setFeedMode(!_showWay2NewsMode);
        },
        backgroundColor: FeedXpressoTheme.fx(context).accent,
        foregroundColor: FeedXpressoTheme.fx(context).title,
        icon: Icon(_showWay2NewsMode ? Icons.view_headline : Icons.view_carousel),
        label: Text(
          _showWay2NewsMode ? 'Classic View' : 'Way2News View',
        ),
      ),
    );
  }
}

// Classic feed screen (original implementation)
class ClassicFeedScreen extends StatelessWidget {
  const ClassicFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('Classic Feed Screen Implementation'),
    );
  }
}
