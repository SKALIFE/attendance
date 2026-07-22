# SKALA Attendance Design System

## 1. Product direction and surface map

SKALA Attendance is a calm, premium native macOS control plane for opening and managing the user's attendance browser. It should feel quiet, legible, and at home beside System Settings and standard macOS utilities. It is an independent open source convenience tool, not an official SKALA or SK AX product.

The app owns three native SwiftUI surfaces: the menu-bar panel, first-run onboarding, and settings. Use a window-style `MenuBarExtra` panel, not a command-only pull-down menu. The panel gives current status and the primary attendance action a stable, readable home.

Real Chrome App Mode is Chrome-owned. Do not restyle, replace, embed, imitate, or place an app UI over its content. The attendance page, Google sign-in, passkeys, and every browser interaction remain inside real Chrome. No WKWebView, Electron, extension, page automation, or browser-content design belongs in this system.

## 2. Foundations and tokens

Use semantic SwiftUI system colors, system fonts, materials, and SF Symbols only. Do not add color assets, custom fonts, web-inspired gradients, brand marks, or external dependencies. Respect the active macOS appearance, accessibility contrast, and accent color.

### Color and material

| Role | SwiftUI choice | Use |
| --- | --- | --- |
| Canvas | `Color(nsColor: .windowBackgroundColor)` | Onboarding and settings backgrounds |
| Surface | `Material.regularMaterial` | Window-style menu-bar panel and grouped emphasis |
| Quiet surface | `Material.thinMaterial` | Secondary grouped content when hierarchy needs separation |
| Primary text | `.primary` | Titles, actions, key status values |
| Secondary text | `.secondary` | Explanations, metadata, inactive status labels |
| Separator | `Divider()` | Section boundaries, never custom rules |
| Accent | `.tint` and the system accent color | Primary button, selected control, active focus |
| Success | `.green` with text or symbol support | Ready state only |
| Caution | `.orange` with text or symbol support | Starting, reconnecting, reset-needed state |
| Error | `.red` with text or symbol support | Connection failure and destructive confirmation |

Never communicate state with color alone. Pair it with Korean text and an SF Symbol where the state needs quick scanning.

### Typography

| Role | SwiftUI style | Weight | Use |
| --- | --- | --- |
| Window title | `.title2` | `.semibold` | Onboarding title and settings section title |
| Panel title | `.headline` | `.semibold` | Menu-bar panel identity |
| Section title | `.headline` | `.semibold` | Settings and onboarding groups |
| Body | `.body` | `.regular` | Explanations and control labels |
| Supporting text | `.callout` | `.regular` | Privacy, Chrome, and update detail |
| Status metadata | `.footnote` | `.regular` | Technical state summaries |
| Compact label | `.caption` | `.medium` | Small, nonessential labels only |

Use Dynamic Type styles directly. Do not hard-code point sizes, tracking, or line height. Korean copy should be short, direct, and left aligned unless a control's native layout requires otherwise.

### Spacing and shape

| Token | Value | Use |
| --- | ---: | --- |
| `space.1` | 4 pt | Icon to label, tight inline detail |
| `space.2` | 8 pt | Related controls and compact rows |
| `space.3` | 12 pt | Row groups and card interior rhythm |
| `space.4` | 16 pt | Standard section content spacing |
| `space.6` | 24 pt | Window padding and major groups |
| `space.8` | 32 pt | Major onboarding separation |
| `radius.control` | 8 pt | Custom grouped surface only when native controls do not supply shape |
| `radius.panel` | 12 pt | Window-style panel grouping only |

Prefer native `Form`, `Section`, `Toggle`, `Picker`, `LabeledContent`, `Button`, and `ContentUnavailableView` before custom containers. Native controls own their standard radius, border, and hover treatment.

## 3. Layout, hierarchy, and responsive behavior

The menu-bar panel is a compact vertical control surface. It starts with the primary action, then shows operational actions, a separated status summary, and low-frequency actions. Keep its useful width between 300 and 360 pt. Make the primary open action visually first, while keeping `창 앞으로 가져오기` and `페이지 새로고침` secondary.

Onboarding is one focused native window. Retain the existing 520 pt baseline width, 24 pt outer padding, and a single clear completion action. Present the unofficial-app notice and no-automation promise before choices. Group Chrome availability, analytics consent, and login-item preference as distinct sections with plain explanatory text.

Settings remains a native tabbed window at the existing 560 by 420 pt baseline. Keep the current order: 일반, 개인정보, 브라우저, 업데이트, 정보. Each tab uses a `Form` with labeled sections. Destructive session reset stays in the 브라우저 tab, visually separated from routine controls and followed by native confirmation.

At larger accessibility sizes, text wraps before controls truncate. Stacks may grow vertically and windows may expand, but controls must keep a 44 pt minimum hit target when custom layout is needed. Do not compress content into a web-style sidebar or dashboard.

## 4. Reusable primitives and states

| Primitive | Anatomy | Default and interaction rules |
| --- | --- | --- |
| `MenuPanel` | Title, primary action, action rows, status group, utility rows | `regularMaterial` background; standard menu-panel dismissal and keyboard behavior; no decorative header |
| `PrimaryAttendanceAction` | `checkmark.rectangle` symbol, `출결 페이지 열기` label, optional progress | Use `.borderedProminent`; disabled only while a mutually exclusive launch is running; show progress and status text while busy |
| `CommandRow` | SF Symbol, text label, optional keyboard equivalent | Standard button hover, pressed, focus, and disabled states; never rely on icon alone |
| `StatusRow` | Status symbol, label, user-facing value | Ready uses checkmark and text; transitional work uses progress; error includes a recovery action nearby |
| `OnboardingSection` | Section title, concise explanation, native control | Clear reading order; selected controls use the system tint; unavailable Chrome blocks start but leaves download and retry available |
| `SettingsSection` | `Form` section with native labels and controls | Keep a single concern per section; use supporting text for irreversible or privacy-sensitive outcomes |
| `DestructiveAction` | Label, warning copy, confirmation dialog | Use system destructive role and red only at the confirmed-action affordance; describe that only the dedicated profile is reset |
| `EmptyOrErrorState` | Symbol, title, short explanation, recovery action | Use `ContentUnavailableView` where it fits; include retry, diagnostics, or download actions as relevant |

All buttons must have an enabled, disabled, hover, pressed, keyboard-focus, and busy state through native SwiftUI behavior. Toggles and pickers must expose selected and disabled states. Confirmation dialogs must offer cancel as the safe default.

## 5. Symbols, copy, and feedback

Use SF Symbols with `.symbolRenderingMode(.hierarchical)` when the system control does not already draw an icon. Approved meanings include `checkmark.rectangle` for the menu-bar identity and attendance action, `arrow.up.right.square` for opening an external page, `arrow.clockwise` for refresh, `macwindow.and.cursorarrow` for bringing Chrome forward, `gearshape` for settings, `exclamationmark.triangle` for recoverable trouble, `checkmark.circle` for ready, and `lock.shield` for privacy.

Symbols support text, never replace it. Keep existing Korean action names where they map to product behavior. Status messages describe the user's next useful fact, such as `Chrome 시작 중`, `모바일 모드 적용 중`, or `연결을 확인할 수 없습니다`. Technical details belong in diagnostics, not the main panel.

Use native `ProgressView` for ongoing work, native alerts and confirmation dialogs for consequential actions, and no toast system. Don't promise automatic attendance, successful sign-in, or passkey completion. The user completes those actions in Chrome.

## 6. Motion and accessibility

Motion is functional only. Use the platform's standard control feedback and `ProgressView` for loading. If an explicit transition is needed, limit it to opacity and transform, keep it brief, and honor `accessibilityReduceMotion`. Do not add ambient animation, bouncing status icons, or animated gradients.

Every control has a visible native focus state, keyboard access, a concise accessibility label, and an accessibility hint when its result is not clear from its title. Pair status colors with text and symbols. Preserve VoiceOver reading order from title to explanation to control to outcome. Support Increase Contrast and differentiate-without-color without custom overrides.

Privacy copy must clearly say that Google account data, attendance details, page content, cookies, and tokens are not collected. Browser reset copy must clearly say that it only removes the dedicated Chrome profile and requires the user to sign in again.

## 7. Scope boundaries and implementation rules

This contract governs only native SwiftUI menu panel, onboarding, and settings work in `SKALAAttendance/MenuBar`, `SKALAAttendance/Onboarding`, and `SKALAAttendance/Settings`. It follows the current shell, whose menu extra is presently command-style, onboarding is a single 520 pt stack, and settings is a five-tab 560 by 420 pt window. Future UI work may replace those default primitives only with the primitives defined here.

Do not change Chrome launch, CDP, profile, analytics, update, authentication, or page-navigation behavior for visual work. Do not redesign the Chrome App Mode window or its web content. Do not introduce dependency-based UI kits, custom brand assets, copied logos, or web UI patterns. Keep the app a native macOS launcher and control plane, with Chrome isolated as the real browser surface.
