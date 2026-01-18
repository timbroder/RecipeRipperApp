# App Icon and Splash Screen TODO

## Status
Placeholder configurations have been created. Actual design assets are needed.

## Requirements

### App Icon
- **Sizes needed for iOS:**
  - 1024x1024 (App Store)
  - 180x180 (iPhone)
  - 167x167 (iPad Pro)
  - 152x152 (iPad)
  - 120x120 (iPhone)
  - 87x87 (iPhone)
  - 80x80 (iPad)
  - 76x76 (iPad)
  - 60x60 (iPhone)
  - 58x58 (iPad)
  - 40x40 (iPad)
  - 29x29 (Settings)

- **Sizes needed for Android:**
  - 192x192 (xxxhdpi)
  - 144x144 (xxhdpi)
  - 96x96 (xhdpi)
  - 72x72 (hdpi)
  - 48x48 (mdpi)

### Design Concept
- Icon should represent recipe extraction from videos
- Suggested elements:
  - Video play button
  - Recipe card or cookbook
  - Chef's hat
  - Cooking utensils
- Color scheme: Warm colors (orange, red) to match app theme

### Splash Screen
- Simple branded splash screen with app icon and name
- Loading indicator
- Consistent with Material Design 3 guidelines

## Tools for Generation
- Use `flutter_launcher_icons` package to generate icons from a single source
- Use `flutter_native_splash` package for splash screen

## Commands
```bash
# After creating icon assets
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## Next Steps
1. Design app icon (use Figma, Adobe Illustrator, or similar)
2. Add icon generation packages to pubspec.yaml
3. Configure icon and splash screen generation
4. Generate assets for both platforms
