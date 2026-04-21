# Theme Revamp: Port the Mail Notifier theme system

This is a hand-off document. It walks you through building the same 10-theme system Mail Notifier 3.2 ships, wired up so every surface in the app recolors live when the user swaps themes.

The reference implementation is in `mac-apps/mail-notifier` (commits after `b6e0666`). Read that commit range to see the actual diffs. This document explains what to build, in what order, and the traps that cost time the first time around.

## What you're building

Ten selectable themes, all live-reactive:

**Auto**
- `System` — follows the user's macOS Appearance (light / dark), flipping when they flip.

**Light**
- `Hoth` — cool whites + glacier blue
- `Risa` — warm pinks + coral
- `Weasley` — burnt orange on parchment
- `Starbuck` — sand + coffee brown

**Dark**
- `Cylon` — red scan line on black
- `Vader` — crimson on aubergine
- `Kirk` — Starfleet gold on navy
- `Hermione` — lilac on plum
- `Nerds` — Strategic Nerds brand: `#121212` background, `#FCDE09` primary

Selection is **machine-local** (UserDefaults, not iCloud) so each Mac keeps its own look.

The selector itself lives in one place: the menu bar popover. Hovering the active dot springs the strip open; clicking a dot applies the theme and snaps the strip closed. No theme selector in the settings drawer — this is an intentional single-source-of-truth call.

## Architecture

Four moving parts.

### 1. `ThemePalette` struct

A flat record of every visual token:

```swift
struct ThemePalette: Equatable {
    let isDark: Bool

    // Surfaces
    let background, surface, card, cardElevated, cardInset: Color

    // Borders + dividers
    let border, borderStrong, borderFocus, divider, dividerSubtle: Color

    // Text hierarchy
    let foreground, foregroundSoft, muted, tertiary, dim: Color

    // Semantic
    let primary, primaryDeep, primaryForeground: Color
    let success, warning, destructive: Color

    // Bridged to AppKit for window chrome
    var nsBackground: NSColor { NSColor(background) }
    var nsAppearance: NSAppearance? { NSAppearance(named: isDark ? .darkAqua : .aqua) }
}
```

Every palette is a static let on `ThemePalette` — `static let cylon`, `static let hoth`, etc.

### 2. `AppTheme` enum

```swift
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case hoth, risa, weasley, starbuck          // light
    case cylon, vader, kirk, hermione, nerds    // dark

    var palette: ThemePalette { /* switch + resolve system at read-time */ }
}
```

The important bit is the `system` case: `.palette` resolves **at read time** based on `NSApp.effectiveAppearance`. Do not cache.

```swift
case .system:
    let isDark = (NSApp?.effectiveAppearance
        .bestMatch(from: [.aqua, .darkAqua]) ?? .aqua) == .darkAqua
    return isDark ? .systemDark : .systemLight
```

### 3. `ThemeStore: ObservableObject`

The singleton that glues everything together:

```swift
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.defaultsKey)
        }
    }

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? AppTheme.cylon.rawValue
        self.current = AppTheme(rawValue: raw) ?? .cylon

        // Re-publish when macOS flips between light/dark and the user is on System.
        appearanceObserver = NSApp?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            guard let self, self.current == .system else { return }
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    var palette: ThemePalette { current.palette }
}
```

The KVO observer is load-bearing. Without it, the System theme doesn't flip when the user toggles macOS Appearance in System Settings.

### 4. SwiftUI environment

```swift
private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .cylon // or whatever your default is
}

extension EnvironmentValues {
    var theme: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}
```

Views read `@Environment(\.theme) private var theme` and then reference `theme.primary`, `theme.background`, etc.

## The reactivity gotcha

The **first approach that doesn't work**: a `.themedRoot()` view modifier that internally owns `@ObservedObject store` and calls `.environment(\.theme, store.current.palette)`. SwiftUI does not reliably refresh the environment of a parent view when an `@ObservedObject` inside a `ViewModifier` changes.

The **approach that works**: each root view (menu bar popover, main window) directly observes `ThemeStore.shared` and pushes the palette into the environment in its own `body`:

```swift
struct MenuBarPopover: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    // ...

    var body: some View {
        let theme = themeStore.palette
        return VStack(spacing: 0) {
            // ... your subviews ...
        }
        .background(theme.background)
        .environment(\.theme, theme)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }
}
```

Two environments:
- `\.theme` → your custom palette struct (used by your views for token reads)
- `\.colorScheme` → forces SwiftUI's own tinting (Pickers, TextFields, Toggles, system Materials) to render as dark/light to match your palette

**Apply this pattern to every separately-hosted view tree.** For Mail Notifier that's (a) the menu bar `NSPopover` content, and (b) the main `NSWindow` content. Each gets its own `@ObservedObject` + `.environment` wiring.

## Window chrome

The `NSWindow` has to follow the palette too — the native titlebar, background, and appearance. Do it via an `NSViewRepresentable` that lives inside the SwiftUI tree and re-applies on every render:

```swift
private struct WindowChrome: NSViewRepresentable {
    let palette: ThemePalette

    func makeNSView(context: Context) -> ChromeView { ChromeView(palette: palette) }

    func updateNSView(_ nsView: ChromeView, context: Context) {
        nsView.palette = palette
        nsView.applyChrome()
    }
}

private final class ChromeView: NSView {
    var palette: ThemePalette
    init(palette: ThemePalette) { self.palette = palette; super.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); applyChrome() }

    func applyChrome() {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.appearance = palette.nsAppearance
        window.backgroundColor = palette.nsBackground
        window.isMovableByWindowBackground = true
    }
}
```

Pass `palette` in from the root `MainView` body. When palette changes, `updateNSView` fires with the new value, and `applyChrome` updates `appearance` / `backgroundColor` live.

## Theme strip UX

Agent Server's pattern, refined:

```swift
private struct ThemeStrip: View {
    @ObservedObject private var store = ThemeStore.shared
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private static let bouncy: Animation = .spring(response: 0.35, dampingFraction: 0.6)
    private static let dotSize: CGFloat = 10

    var body: some View {
        HStack(spacing: isExpanded ? 6 : 0) {
            ForEach(AppTheme.allCases) { option in
                let palette = option.palette
                let isActive = store.current == option
                let show = isExpanded || isActive

                Button {
                    withAnimation(Self.bouncy) {
                        store.current = option
                        isExpanded = false
                    }
                } label: {
                    ZStack {
                        dotFill(for: option, palette: palette)
                        if isActive {
                            Circle()
                                .stroke(theme.foreground.opacity(0.9), lineWidth: 1.5)
                                .padding(-2.5)
                        }
                    }
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .scaleEffect(show ? 1 : 0.01)
                    .opacity(show ? 1 : 0)
                }
                .buttonStyle(.plain)
                .frame(width: show ? Self.dotSize : 0)
                .clipped()
                .help(option.label)
            }
        }
        .padding(.horizontal, isExpanded ? 9 : 6)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.card))
        .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
        .animation(Self.bouncy, value: isExpanded)
        .onHover { hovering in
            withAnimation(Self.bouncy) {
                isExpanded = hovering
            }
        }
    }

    @ViewBuilder
    private func dotFill(for option: AppTheme, palette: ThemePalette) -> some View {
        if option == .system {
            // Split black/white disc so users recognize "auto-adapt".
            ZStack {
                Circle().fill(Color.white)
                Circle()
                    .fill(Color.black)
                    .mask(
                        Rectangle()
                            .frame(width: Self.dotSize, height: Self.dotSize)
                            .offset(x: Self.dotSize / 2)
                    )
            }
        } else {
            Circle()
                .fill(LinearGradient(
                    colors: [palette.primary, palette.primaryDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        }
    }
}
```

Key details:
- Non-active dots collapse to `.frame(width: 0)` + `.scaleEffect(0.01)` + `.opacity(0)`, wrapped in `.clipped()`. They don't just dim — they vanish.
- The active dot stays visible; hover reveals the rest.
- System gets a split black/white disc so it reads as "auto".
- The active-ring uses `theme.foreground` (from env) so it contrasts against any background.

## Step-by-step migration for meeting-notifier

Assuming the app looks like Mail Notifier did pre-theme-revamp: static `Color.appX` tokens sprinkled through views, no theme selector.

### 1. Create `Models/ThemeStore.swift`

Copy the file from Mail Notifier verbatim. Change `defaultsKey` to something app-scoped if you want, but `"appTheme"` is fine.

### 2. Create `Views/Theme.swift`

Strip it down to `AppRadius` + `AppSpacing` enums. Delete any static `Color.appX` extensions you may have had — they become dead code once you migrate callers.

### 3. Update `SharedComponents.swift` (or equivalent)

Every shared component (card, row, buttons, pickers) reads `@Environment(\.theme)` and uses `theme.X`. Pattern:

```swift
struct AppCard<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ... use theme.tertiary, theme.card, theme.border throughout
        }
    }
}
```

For buttons that want semantic tints, use an enum rather than passing `Color` directly:

```swift
enum AppButtonTint { case foreground, primary, destructive }

struct AppSecondaryButton: View {
    var tint: AppButtonTint = .foreground
    @Environment(\.theme) private var theme
    // Resolve to theme.foreground / theme.primary / theme.destructive inside body.
}
```

This way consumers write `tint: .destructive` and get the themed red, not a hardcoded color.

### 4. Migrate every view

In each view file:

1. Add `@Environment(\.theme) private var theme` to the struct.
2. Replace every `Color.appX` with `theme.X`. A `sed` loop helps:
   ```bash
   for f in Views/*.swift Views/**/*.swift; do
     sed -i '' \
       -e 's/Color\.appBackground/theme.background/g' \
       -e 's/Color\.appPrimary/theme.primary/g' \
       # … all the others …
       "$f"
   done
   ```
3. For private subviews inside the same file (rows, headers), **they each need their own** `@Environment(\.theme)`. Environment reads don't inherit from the enclosing type.

### 5. Wire roots

Every top-level hosted SwiftUI tree:

```swift
struct MyRoot: View {
    @ObservedObject private var themeStore = ThemeStore.shared

    var body: some View {
        let theme = themeStore.palette
        return content
            .background(theme.background)
            .environment(\.theme, theme)
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }
}
```

For menu bar apps, that's:
- `NSPopover`'s `contentViewController` root view
- `NSWindow`'s hosting view root (plus `WindowChrome` NSViewRepresentable for titlebar + background)

### 6. Build the theme strip

Put it in the menu bar popover's bottom bar. Do not duplicate it in the settings drawer — one canonical location keeps the mental model clean.

### 7. Purge legacy tokens

After migration, grep for any remaining `Color.app` references and purge them. Delete the old static extensions from `Theme.swift` so the compiler catches any that slipped through.

```bash
grep -rn "Color\.app[A-Z]" Views/ Models/
```

Should return nothing.

### 8. Smoke test each theme

Launch the app. In the theme strip, click each of the 10 options. Verify every surface recolors:
- Window background
- Sidebar (if any) selection highlight + icons
- Card backgrounds and borders
- Text hierarchies (foreground / muted / tertiary)
- Toggles and pickers
- Primary buttons
- Destructive buttons
- Focused field borders
- Titlebar (light themes should use aqua, dark should use darkAqua)

Especially test **System**: toggle macOS between light and dark in System Settings → General → Appearance with the app running and focused on the popover. Everything should flip within one runloop tick.

## Common traps, ranked by how much time they'll cost

1. **Private subviews missing `@Environment(\.theme)`.** Compile error: "cannot find 'theme' in scope" inside a ForEach row or header struct. Each `View` type needs its own environment declaration.

2. **Forgetting the KVO observer for System.** App stays on the appearance it launched with forever. The observer must live on `ThemeStore.shared` and be set up in its init.

3. **`.environment(\.colorScheme, …)` omission.** Native SwiftUI controls (Picker menus, TextField cursor, Toggle switch) keep rendering with the host window's appearance, which looks wrong when you pick a dark theme under a light system appearance (or vice versa). Always set both `\.theme` and `\.colorScheme` at the root.

4. **Window chrome not updating.** `NSViewRepresentable.updateNSView` must re-apply chrome. Storing palette only in `makeNSView` leaves you with a stale appearance after swap.

5. **Using the ForEach loop variable as `theme`.** In the theme strip, the enum case is iterated — name it `option`, not `theme`, or it'll shadow your env binding for the active-ring color.

6. **`@StateObject` for `ThemeStore.shared`.** Use `@ObservedObject`. `@StateObject` is for views that own the instance; a global singleton is observed, not owned.

7. **Toggle `.tint` with a palette color.** Works, but Toggle caches its tint unless the `body` actually recomputes. Because you're already re-computing `body` via `themeStore.palette` at the root, this is fine — but if you use a cached child view, tints may stale. Keep the tint read inside the `body` hierarchy, not in a `private let`.

8. **Encoding palette colors as hex literals.** The palette struct holds `Color` values. For hex readability, pass `Color(red: 0xFC/255, green: 0xDE/255, blue: 0x09/255)` — that's how Mail Notifier's palette reads. Consistent, greppable, diff-friendly.

## File checklist

When you're done, you should have:

- `Models/ThemeStore.swift` — palette struct, 10 static palettes, AppTheme enum, ThemeStore singleton, EnvironmentValues extension
- `Views/Theme.swift` — only `AppRadius` + `AppSpacing` (no Color extensions)
- `Views/Components/SharedComponents.swift` — all shared building blocks themed
- Every view file — `@Environment(\.theme)` added, no `Color.app*` references
- Menu bar popover bottom bar — ThemeStrip view
- Main window root — `WindowChrome(palette:)` NSViewRepresentable observing palette changes

No file outside `Views/` should reference `theme` or `ThemeStore`. Services, models, managers stay palette-agnostic.

## What you get

- Full recolor across the entire app in under 200ms when the user picks a theme.
- Automatic flip when macOS Appearance changes (System theme).
- Per-Mac theme selection (no iCloud leakage — that's intentional).
- One file (`ThemeStore.swift`) owns every color in the app.
- Future new themes: add a static palette + add the case to the enum. Everything else works.

## Reference commits

In `mac-apps/mail-notifier`, the full history is:
- Initial scaffold + main window + drawer rewrite
- Theme env + selector (partial reactivity — skip this one, it's the bug you don't want to replicate)
- Full `ThemePalette` rewrite + 8 themes + reactive roots
- System theme KVO + Nerds theme + 3.2.0 release

Read the last two in order for a working reference.
