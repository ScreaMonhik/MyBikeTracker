# MyBikeTracker — Trail Dawn

Brand book for the iOS app. Tokens live in `MyBikeTracker/DesignSystem/Brand.swift`.

## Promise

Ride with intention. The product feels like first light on a quiet trail: warm, precise, and ready to move.

## Personality

- **Calm confidence** — never shouty, never generic fitness-blue
- **Outdoor warmth** — parchment, pine, and ember instead of cold gray
- **Motion-first** — numbers breathe, live state pulses, actions spring
- **Thumb-native** — primary ride controls sit in the lower third

## Logo and name

- Product name: **MyBikeTracker**
- Voice: short, human, present tense
- Icon: bicycle + trail line on a forest-to-ember wash
- Do not replace the mark with a letterform

## Color

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Canvas | `#F3EEE6` | `#0A100E` | Screen wash |
| Surface | `#FFFCF7` | `#141C19` | Cards |
| Ink | `#13201B` | `#F4F0E8` | Titles, metrics |
| Muted | `#5E6B66` | `#9AABA4` | Labels |
| Trail | `#1B7A6E` | `#4AD1C3` | Brand, history lines, selected chrome |
| Ember | `#E85A32` | `#FF7A4D` | Start, live energy, today |
| Meadow | `#2F8F5B` | `#5FD08A` | Success, recording |
| Amber | `#C9841D` | `#E8B04A` | Pause, chain due |
| Danger | `#D64545` | `#FF6B6B` | Stop, delete |

Accent color in the asset catalog matches Trail so system controls stay on-brand.

## Type

- Display and metrics: **SF Rounded**, bold, tabular figures
- UI: **SF Pro**, semibold for titles
- Never track metrics tighter than default; they must stay readable on the bike

## Shape and depth

- Cards: 24pt continuous corners
- Pills: capsule
- Hairline stroke + soft 16pt shadow
- Map chrome: Liquid Glass on iOS 26, material fallback earlier

## Motion

- Appear: spring 0.48 / 0.82
- Tap and tabs: spring 0.32 / 0.78
- Goal ring: slower spring 0.92 / 0.86
- Live badge: 0.7s pulse
- Honor Reduce Motion — fade only, no pulse

## Sound and haptics

- Tab change: selection
- Start ride: success
- Pause / resume: light impact
- Stop prompt: warning

## Voice

- Buttons: verbs (`Start`, `Pause`, `Save`)
- Empty states: one line of permission, one line of next step
- No exclamation marks in chrome

## Do / don’t

- Do keep the map as the hero on Map and Trip
- Do use Ember only for energy (start, today, live emphasis)
- Don’t use system blue for brand surfaces
- Don’t crowd metrics; three across is the maximum in a HUD row
