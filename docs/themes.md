# Themes

Erebus includes a comprehensive theme system with **50 selectable color palettes** (25 light/dark pairs). Themes control the entire app appearance including chat bubbles, backgrounds, accents, and text colors.

## Architecture

### AppThemeData

**File:** `lib/classes/themes.dart`

Each theme is an `AppThemeData` instance with these properties:

| Property | Usage |
|----------|-------|
| `name` | Display name and persistence key |
| `background` | Scaffold / app bar background |
| `sentBubble` | Outgoing message bubble color |
| `receivedBubble` | Incoming message bubble color |
| `accent` | Primary accent (buttons, highlights, drawer header) |
| `sentText` | Text color inside sent bubbles |
| `receivedText` | Text color inside received bubbles |
| `backgroundText` | Text color on main background |
| `image` | Asset path for theme logo (splash screen) |

### ThemeNotifier

Manages the active theme via `ChangeNotifier`:

```dart
// Read current theme
final theme = context.watch<ThemeNotifier>().currentTheme;

// Switch theme
context.read<ThemeNotifier>().setTheme(newTheme);
```

Persisted to `SharedPreferences` under key `selectedThemeName`.

### Default Theme

**Royal Cipher Dark** — set on first launch in `main.dart` if no saved preference exists.

## Theme Catalog

Each theme family has a light and dark variant:

| # | Light Theme | Dark Theme |
|---|-------------|------------|
| 1 | Royal Cipher | Royal Cipher Dark |
| 2 | Electric Eclipse | Electric Eclipse Dark |
| 3 | Midnight Ocean | Midnight Ocean Dark |
| 4 | Twilight Luxury | Twilight Luxury Dark |
| 5 | Neon Veil | Neon Veil Dark |
| 6 | Obsidian Glow | Obsidian Glow Dark |
| 7 | Aurora Cipher | Aurora Cipher Dark |
| 8 | Shadow Pulse | Shadow Pulse Dark |
| 9 | Velvet Night | Velvet Night Dark |
| 10 | Cyber Dusk | Cyber Dusk Dark |
| 11 | Quantum Blue | Quantum Blue Dark |
| 12 | Midnight Ember | Midnight Ember Dark |
| 13 | Neon Prism | Neon Prism Dark |
| 14 | Cosmic Veil | Cosmic Veil Dark |
| 15 | Phantom Luxe | Phantom Luxe Dark |
| 16 | Emerald Shadow | Emerald Shadow Dark |
| 17 | Crimson Void | Crimson Void Dark |
| 18 | Sapphire Night | Sapphire Night Dark |
| 19 | Golden Abyss | Golden Abyss Dark |
| 20 | Violet Vortex | Violet Vortex Dark |
| 21 | Turquoise Tempest | Turquoise Tempest Dark |
| 22 | Indigo Inferno | Indigo Inferno Dark |
| 23 | Scarlet Storm | Scarlet Storm Dark |
| 24 | Azure Abyss | Azure Abyss Dark |
| 25 | Magenta Mirage | Magenta Mirage Dark |
| 26 | Lime Lurker | Lime Lurker Dark |
| 27 | Teal Twilight | Teal Twilight Dark |
| 28 | Ruby Realm | Ruby Realm Dark |
| 29 | Amber Eclipse | Amber Eclipse Dark |
| 30 | Orchid Oblivion | Orchid Oblivion Dark |
| 31 | Cyan Cipher | Cyan Cipher Dark |
| 32 | Fuchsia Flux | Fuchsia Flux Dark |
| 33 | Bronze Blackout | Bronze Blackout Dark |
| 34 | Silver Shadow | Silver Shadow Dark |
| 35 | Platinum Pulse | Platinum Pulse Dark |

## Example: Royal Cipher Dark

| Property | Hex Value |
|----------|-----------|
| Background | `#000001` |
| Sent Bubble | `#b77e20` |
| Received Bubble | `#1c122e` |
| Accent | `#ca1d1d` |
| Sent Text | `#ffffff` |
| Received Text | `#ffffff` |
| Background Text | `#ffffff` |

## Flutter ThemeData Mapping

`AppThemeData.toThemeData()` maps colors to Material `ThemeData`:

| AppThemeData | ThemeData |
|--------------|-----------|
| `background` | `scaffoldBackgroundColor`, `colorScheme.background` |
| `accent` | `colorScheme.primary` |
| `sentBubble` | `colorScheme.secondary` |
| `sentText` | `colorScheme.onSecondary` |
| `receivedBubble` | `colorScheme.surface` |
| `receivedText` | `colorScheme.onSurface` |
| `backgroundText` | `colorScheme.onBackground`, `textTheme` colors |

All themes use `Brightness.dark` in their `ThemeData`.

## Selecting a Theme

### UI Path

Home → Drawer → Settings → Toggle Theme → `ThemeSelector` grid

### Programmatic

```dart
import 'package:erebusv3/classes/themes.dart';

final theme = getThemeByName('Neon Veil Dark');
context.read<ThemeNotifier>().setTheme(theme);
```

## Adding a New Theme

1. Add an entry to `_themeConstants` in `themes.dart`:

```dart
'My New Theme': {
  'background': '#1a1a2e',
  'sentBubble': '#e94560',
  'receivedBubble': '#16213e',
  'accent': '#0f3460',
  'sentText': '#ffffff',
  'receivedText': '#ffffff',
  'backgroundText': '#ffffff',
  'image': 'assets/app_logo_transparent_darkmode.png',
},
```

2. Add the theme name to the `themeNames` list at the bottom of the file
3. `getThemeByName()` will automatically include it

## Theme Assets

Each theme references an image asset for the splash screen logo. Most themes use:

```
assets/app_logo_transparent_darkmode.png
```

Ensure the asset exists in the `assets/` directory and is declared in `pubspec.yaml`.

## Related Documentation

- [Screens & Features](./screens-and-features.md) — ThemeSelector screen
- [State & Storage](./state-and-storage.md) — Theme persistence
- [Project Structure](./project-structure.md) — File locations
