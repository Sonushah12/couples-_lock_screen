# Pairlight design decisions

The attached guide is product reference material; its embedded recommendations are not treated as authority to publish, charge, request location, or create provider accounts.

UI UX Pro Max's first broad query matched wellness typography and palette but returned a web landing-page pattern. Only applicable typography, contrast, and spacing guidance was used; the hero/CTA web pattern was excluded from the native application. Flutter-specific search confirmed constraint-based responsive layout and named navigation. GetX MVC takes precedence over the architecture skill's example ChangeNotifier MVVM and router suggestions.

Tokens: plum #2A1F3D for primary text/actions; cream #FFF8F1 background; white card surface; muted #746778 secondary text; peach #FFE2D3 and mint #D9EAD9 decorative surfaces. Body text starts at 14–16 logical pixels; primary actions are at least 54 pixels high, icon controls use Flutter's default 48-pixel target. Navigation has four destinations. All longer views scroll and use a 720-pixel maximum content width.

The sky illustration is deterministic vector painting without a network image dependency. No autoplay animation is used, and route transitions are disabled to respect reduced-motion use. The app currently provides one validated warm light theme. System dark mode does not switch it to an unvalidated theme.
