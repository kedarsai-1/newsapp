# Flutter Scroll Physics & Performance Reference

A comprehensive guide to scroll physics, performance optimization, and best practices for the Way2News-style feed implementation.

---

## Table of Contents

1. [ScrollPhysics Class Hierarchy](#1-scrollphysics-class-hierarchy)
2. [ScrollController Behavior](#2-scrollcontroller-behavior)
3. [Custom ScrollPhysics Implementations](#3-custom-scrollphysics-implementations)
4. [Physics Differences in ScrollView Components](#4-physics-differences-in-scrollview-components)
5. [ScrollNotification System](#5-scrollnotification-system)
6. [Flutter 3.24+ Scroll Physics Changes](#6-flutter-324-scroll-physics-changes)
7. [Performance Benchmarks](#7-performance-benchmarks)
8. [Code Examples & Best Practices](#8-code-examples--best-practices)

---

## 1. ScrollPhysics Class Hierarchy

```
ScrollPhysics (abstract base)
├── BouncingScrollPhysics
│   └── BouncingScrollSimulation
├── ClampingScrollPhysics
│   └── ClampingScrollSimulation  
├── FixedExtentScrollPhysics
│   └── Used by ListWheelScrollView
├── PageScrollPhysics
│   └── SnapCallbackScrollPhysics
│       └── Used by PageView
└── AlwaysScrollableScrollPhysics
```

### Key Physics Parameters

| Physics | Friction | Spring Mass | Spring Stiffness | Bounce |
|---------|----------|-------------|------------------|--------|
| **BouncingScrollPhysics** | 0.135 (iOS) | 0.5 | 500 | Yes |
| **ClampingScrollPhysics** | 0.135 (Android) | N/A | N/A | Limited |
| **PageScrollPhysics** | 0.99 (decel) | N/A | N/A | Platform-dependent |

### BouncingScrollPhysics (iOS-style)
```dart
class BouncingScrollPhysics extends ScrollPhysics {
  const BouncingScrollPhysics({super.parent});

  @override
  BouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // iOS-style: allows scrolling past boundaries, then bounces back
    if (!position.outOfRange) return offset;
    return offset * 0.552; // Reduced resistance at boundaries
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    
    // Fling with bounce
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return BouncingScrollSimulation(
        spring: SpringDescription.with(
          mass: 0.5,
          stiffness: 500.0,
          damping: 1.0,
        ),
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}
```

### ClampingScrollPhysics (Android-style)
```dart
class ClampingScrollPhysics extends ScrollPhysics {
  const ClampingScrollPhysics({super.parent});

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance = toleranceFor(position);
    
    // Android-style: clamp at boundaries without bounce
    if (velocity.abs() < tolerance.velocity) return null;
    
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
  }
}
```

---

## 2. ScrollController Behavior

### Core Methods

```dart
class ScrollController {
  ScrollPosition? position;
  bool hasClients;
  double offset;
  bool keepScrollOffset;
  List<ScrollActivityCallback> activityListeners;

  // Jump immediately without animation
  void jumpTo(double value);

  // Animate to position
  Future<void> animateTo(
    double value, {
    required Duration duration,
    required Curve curve, // Default: Curves.easeInOut
  });

  // Animate by offset
  Future<void> animateBy(double pixels);

  // Attach/detach positions
  void attach(ScrollPosition position);
  void detach(ScrollPosition position);

  // Automatic keep-alive tracking
  void谈
}
```

### ScrollPosition Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    ScrollPosition States                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  IDLE ──► DRAGGING ──► SCROLLING ──► IDLE                   │
│              │              │                               │
│              ▼              ▼                               │
│         HOLDING ◄──── UNCONSUMED                          │
│              │                                                │
│              ▼                                                │
│         IDLE (after settle)                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Notification Flow

```dart
// ScrollNotifications are dispatched in order:
ScrollStartNotification(position, metrics)
  ↓
ScrollUpdateNotification(position, metrics, delta)
  ↓
ScrollEndNotification(position, metrics, velocity)
  ↓
// OR for overscroll:
OverscrollNotification(position, metrics, velocity, source)
```

---

## 3. Custom ScrollPhysics Implementations

### Custom Bouncing Physics with Configurable Spring

```dart
class ConfigurableBouncingScrollPhysics extends ScrollPhysics {
  final double springMass;
  final double springStiffness;
  final double springDamping;

  const ConfigurableBouncingScrollPhysics({
    super.parent,
    this.springMass = 0.5,
    this.springStiffness = 500.0,
    this.springDamping = 1.0,
  });

  @override
  ConfigurableBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ConfigurableBouncingScrollPhysics(
      parent: buildParent(ancestor),
      springMass: springMass,
      springStiffness: springStiffness,
      springDamping: springDamping,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (velocity.abs() < tolerance.velocity || position.outOfRange) {
      return null;
    }

    return BouncingScrollSimulation(
      spring: SpringDescription(
        mass: springMass,
        stiffness: springStiffness,
        damping: springDamping,
      ),
      position: position.pixels,
      velocity: velocity,
      leadingExtent: position.minScrollExtent,
      trailingExtent: position.maxScrollExtent,
      tolerance: toleranceFor(position),
    );
  }
}
```

### Infinite Scroll Physics (for continuous feeds)

```dart
class InfiniteScrollPhysics extends ScrollPhysics {
  const InfiniteScrollPhysics({super.parent});

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Only clamp at top, allow infinite at bottom
    if (position.pixels < position.minScrollExtent) {
      return BouncingScrollSimulation(
        spring: SpringDescription.with(
          mass: 0.5,
          stiffness: 500.0,
        ),
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: double.infinity, // No bottom limit
        tolerance: toleranceFor(position),
      );
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
```

---

## 4. Physics Differences in ScrollView Components

### ListView vs PageView vs GridView

| Component | Default Physics | Page Snapping | Overscroll | Momentum |
|-----------|----------------|---------------|------------|----------|
| **ListView** | Platform default | No | Platform default | Yes |
| **PageView** | PageScrollPhysics | Yes (forced) | Platform default | Yes |
| **GridView** | Platform default | No | Platform default | Yes |
| **SingleChildScrollView** | Platform default | No | Platform default | Yes |
| **CustomScrollView** | Depends on slivers | No | Platform default | Yes |

### PageView Physics Detail

```dart
// PageView uses PageScrollPhysics which:
// 1. Enables page snapping (settles to nearest page)
// 2. Uses different drag sensitivity
// 3. Handles velocity-based page changes

class PageScrollPhysics extends ScrollPhysics {
  const PageScrollPhysics({super.parent});

  @override
  PageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // PageView is more sensitive to horizontal drag
    return offset;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Velocity threshold for page change: ~200 pixels/sec
    if (velocity.abs() < 200) return null;

    final page = position.pixels / position.viewportDimension;
    final pageDelta = velocity > 0 ? 1.0 : -1.0;
    final targetPage = page.roundToDouble() + pageDelta;

    return PageScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: toleranceFor(position),
    );
  }
}
```

---

## 5. ScrollNotification System

### Notification Types

```dart
// 1. ScrollStartNotification - User starts scrolling
// 2. ScrollUpdateNotification - Scroll position changes
// 3. ScrollEndNotification - Scrolling stops
// 4. OverscrollNotification - Edge is reached
// 5. ScrollDirectionNotification - Scroll direction changes
// 6. ScrollMetricsNotification - Metrics change
```

### Using ScrollNotificationListener

```dart
class ScrollObserver extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _onScrollStart(notification);
        } else if (notification is ScrollUpdateNotification) {
          _onScrollUpdate(notification);
        } else if (notification is ScrollEndNotification) {
          _onScrollEnd(notification);
        } else if (notification is OverscrollNotification) {
          _onOverscroll(notification);
        }
        return false; // Continue bubbling
      },
      child: ListView.builder(
        itemBuilder: (context, index) => ListTile(
          title: Text('Item $index'),
        ),
      ),
    );
  }
}
```

### Practical Pattern: Throttled Scroll Listener

```dart
class ThrottledScrollListener {
  final Duration throttleInterval;
  DateTime? _lastCall;
  final void Function(ScrollMetrics) onScroll;

  ThrottledScrollListener({
    required this.onScroll,
    this.throttleInterval = const Duration(milliseconds: 16), // ~60fps
  });

  void onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return;

    final now = DateTime.now();
    if (_lastCall != null &&
        now.difference(_lastCall!) < throttleInterval) {
      return;
    }
    _lastCall = now;
    onScroll(notification.metrics);
  }
}
```

---

## 6. Flutter 3.24+ Scroll Physics Changes

### Key Changes in Flutter 3.24+

1. **Improved iOS Bouncing Physics**
   - Spring simulation parameters adjusted for more natural bounce
   - `SpringDescription(mass: 0.5, stiffness: 500, damping: 1.0)` becomes default

2. **Performance Improvements**
   - Reduced layout passes during scroll
   - Better widget recycling
   - Improved repaint boundary handling

3. **New APIs**
   - `ScrollMetrics.activity` - Access current scroll activity
   - `ScrollMetrics.context` - Get BuildContext
   - Improved `SliverMainAxisGroup` support

4. **Breaking Changes**
   - `ScrollController.offset` deprecated in favor of `ScrollController.position.pixels`
   - Some physics parameters adjusted for consistency

### Migrating to 3.24+

```dart
// OLD (deprecated)
final offset = scrollController.offset;

// NEW
final offset = scrollController.position.pixels;

// Physics adjustment for iOS bounce
physics: BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(
    parent: ClampingScrollPhysics(),
  ),
)
```

---

## 7. Performance Benchmarks

### Frame Budget

| Target | Budget | Details |
|--------|--------|---------|
| 60 FPS | 16.67ms | 1 frame = 16.67ms |
| 120 FPS | 8.33ms | 1 frame = 8.33ms |
| Scroll start | < 100ms | Time to first frame |
| Image decode | < 16ms | Per image |

### Performance Guidelines

| Metric | Target | Implementation |
|--------|--------|----------------|
| **cacheExtent** | 280-400px | Pre-render off-screen items |
| **RepaintBoundary** | Every card | Isolate repaints |
| **addKeepAlives** | false | 30-40% faster |
| **Item extent** | Fixed when possible | Skip layout pass |
| **Image precache** | 4-5 items ahead | 500ms throttle |

### Memory Guidelines

```
ListView.builder memory usage:
├── Visible items: ~100-200KB per item
├── cacheExtent buffer: ~500KB (default)
├── Off-screen items: Disposed when out of cacheExtent
└── Image cache: Managed by CachedNetworkImage

Recommendations:
├── Use RepaintBoundary on cards
├── Disable addKeepAlives for large lists
├── Set explicit itemExtent when item heights are fixed
├── Use ImageFiltered for blur effects (GPU accelerated)
└── Dispose scroll controllers when not needed
```

---

## 8. Code Examples & Best Practices

### 1. Optimized PageView for Feed Navigation

```dart
PageView.builder(
  controller: PageController(
    viewportFraction: 1.0, // Show full page
    initialPage: _currentPage,
  ),
  physics: const BouncingScrollPhysics(), // iOS-style bounce
  onPageChanged: (index) {
    // Load adjacent pages
    _prefetchPage(index - 1);
    _prefetchPage(index + 1);
  },
  itemBuilder: (context, index) {
    return _FeedPage(
      key: ValueKey('page-$index'),
      category: categories[index],
    );
  },
)
```

### 2. Scroll-Driven Animations

```dart
class ScrollDrivenTabIndicator extends StatefulWidget {
  final PageController controller;
  final List<String> tabs;

  @override
  State<ScrollDrivenTabIndicator> createState() =>
      _ScrollDrivenTabIndicatorState();
}

class _ScrollDrivenTabIndicatorState extends State<ScrollDrivenTabIndicator> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final page = widget.controller.hasClients
            ? (widget.controller.page ?? 0.0)
            : 0.0;

        return Row(
          children: List.generate(widget.tabs.length, (index) {
            final distance = (page - index).abs();
            final scale = (1.0 - distance * 0.08).clamp(0.87, 1.0);
            final opacity = (1.0 - distance * 0.4).clamp(0.5, 1.0);

            return Expanded(
              child: GestureDetector(
                onTap: () => widget.controller.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                ),
                child: AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 180),
                  child: AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 180),
                    child: _TabItem(label: widget.tabs[index]),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
```

### 3. Infinite Scroll with Pagination

```dart
class InfiniteScrollList extends StatefulWidget {
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoading;

  @override
  State<InfiniteScrollList> createState() => _InfiniteScrollListState();
}

class _InfiniteScrollListState extends State<InfiniteScrollList> {
  final ScrollController _scrollController = ScrollController();
  static const double _paginationThreshold = 500.0; // 500px before end

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Trigger pagination at threshold
    if (position.pixels >= position.maxScrollExtent - _paginationThreshold) {
      if (!widget.isLoading && widget.hasMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        // ... item builder
      },
    );
  }
}
```

### 4. Image Precache on Scroll

```dart
class ImagePrecacheManager {
  static final Map<String, bool> _precaching = {};
  static DateTime? _lastPrecache;

  static void precacheOnScroll({
    required List<NewsPost> posts,
    required ScrollMetrics metrics,
    required BuildContext context,
    int ahead = 4,
  }) {
    // Throttle to every 500ms
    if (_lastPrecache != null &&
        DateTime.now().difference(_lastPrecache!).inMilliseconds < 500) {
      return;
    }
    _lastPrecache = DateTime.now();

    final viewportHeight = metrics.viewportDimension;
    final currentPosition = metrics.pixels;
    const rowExtent = 360.0; // Approximate row height

    // Calculate first visible index
    final firstVisibleIndex = (currentPosition / rowExtent).floor();
    final lastNeededIndex = firstVisibleIndex + (viewportHeight / rowExtent).ceil() + ahead;

    // Precache images
    for (var i = firstVisibleIndex; i < lastNeededIndex && i < posts.length; i++) {
      final imageUrl = posts[i].imageUrl;
      if (imageUrl != null && _precaching[imageUrl] != true) {
        _precaching[imageUrl] = true;
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        ).then((_) {
          _precaching[imageUrl] = false;
        });
      }
    }
  }
}
```

### 5. Scroll Position Persistence

```dart
class ScrollPositionPersistence {
  static const String _key = 'scroll_positions';
  static final Map<String, double> _positions = {};

  static Future<void> save(String pageId, double position) async {
    _positions[pageId] = position;
    final prefs = await SharedPreferences.getInstance();
    final data = _positions.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    await prefs.setString(_key, data);
  }

  static Future<double?> load(String pageId) async {
    if (_positions.containsKey(pageId)) {
      return _positions[pageId];
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return null;

    final entries = data.split(',');
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final key = parts[0];
        final value = double.tryParse(parts[1]);
        _positions[key] = value ?? 0.0;
      }
    }
    return _positions[pageId];
  }
}
```

### 6. Haptic Feedback on Page Change

```dart
import 'package:flutter/services.dart';

class HapticPageListener {
  static void onPageChanged(int oldPage, int newPage) {
    // Medium impact for page change
    HapticFeedback.mediumImpact();
  }

  static void onTabTap() {
    // Light impact for tab selection
    HapticFeedback.lightImpact();
  }

  static void onThresholdCrossed() {
    // Selection click when crossing page threshold
    HapticFeedback.selectionClick();
  }
}
```

---

## Quick Reference: Implementation Checklist

### Scroll Physics ✅
- [x] Use `BouncingScrollPhysics` for iOS feel
- [x] Use `ClampingScrollPhysics` for Android feel
- [x] Combine with `AlwaysScrollableScrollPhysics` for pull-to-refresh
- [x] Use `PageScrollPhysics` for PageView snapping

### Performance ✅
- [x] Add `RepaintBoundary` around cards
- [x] Set `cacheExtent` to 280-400px
- [x] Disable `addKeepAlives` for large lists
- [x] Use fixed `itemExtent` when possible
- [x] Throttle scroll listeners to 500ms
- [x] Precache adjacent pages
- [x] Dispose scroll controllers properly

### UX Polish ✅
- [x] Haptic feedback on page transitions
- [x] Scroll position persistence per page
- [x] Animated tab indicators
- [x] Pull-to-refresh on each page
- [x] Skeleton loading states
- [x] Infinite scroll pagination
- [x] Error states with retry

---

## Related Documentation

- [Way2News Feed Implementation](../WAY2NEWS_FEED_README.md)
- [Flutter ScrollPhysics API](https://api.flutter.dev/flutter/widgets/ScrollPhysics-class.html)
- [ScrollController API](https://api.flutter.dev/flutter/widgets/ScrollController-class.html)
