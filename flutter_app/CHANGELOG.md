# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Preparation for v1.1.0 release

## [1.1.0] - 2024-12-01

### Added
- Premium features with enhanced customization options
- Advanced AI chat functionality with local model support
- Weather widget with real-time updates
- Video playlist management with offline caching
- Multi-language support for Tamil, Kannada, Bengali, and Malayalam
- Hyperlocal news discovery based on user location
- Push notification system for breaking news
- Social sharing integration for articles

### Changed
- Redesigned home screen with category-based navigation
- Improved article detail view with related content
- Enhanced user profile with activity tracking
- Updated app icons and launch screen
- Migration to material design 3.0

### Fixed
- Fixed image loading caching issues in offline mode
- Resolved navigation errors in deep links
- Fixed authentication state persistence
- Improved error handling for network failures
- Fixed video playback on low memory devices

### Performance Improvements
- Implemented article caching for offline reading
- Optimized image loading with lazy loading
- Added background data fetching for faster startup
- Reduced app size by 25% through asset optimization

### Known Issues
- Some devices with Android 6.0 may experience slow startup
- Voice recognition in AI chat may not work in all languages
- Weather widget may require manual refresh on some carriers

## [1.0.0] - 2024-10-15

### Added
- Initial release of News App
- Multi-role support (Reporter, User, Admin)
- News feed with category filtering
- User authentication and profiles
- Article bookmarking
- Push notifications
- Breaking news alerts
- Reporter publishing tools
- Admin dashboard
- Comment system
- Social sharing

### Changed
- Implemented modern Flutter app architecture
- Added responsive design for all screen sizes
- Material Design UI with custom themes

### Fixed
- Initial bug fixes and performance optimizations
- Fixed login session persistence
- Resolved image loading issues

### Performance Improvements
- Optimized initial app startup time
- Implemented efficient data caching
- Reduced memory usage

### Known Issues
- Limited language support initially
- Some features require stable internet connection
- Initial device setup may be slow on older hardware