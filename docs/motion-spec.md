# Pairlight motion

Source skill: https://github.com/zakariaf/Flutter-Skills/tree/main/skills/motion-and-haptics
Downloaded to `docs/vendor-skills/motion-and-haptics`; applied with Flutter's official animation APIs.

| Moment | Trigger | Change | Duration role | Haptic | Reduced motion |
|---|---|---|---|---|---|
| Press | Pointer down | Ripple and gentle scale | press 100 ms | none | ripple only |
| Selection | Tab or setting committed | Selected fill, fade through | quick 180 ms | selection | instant selection |
| Page reveal | Screen opens | Fade and short vertical rise | reveal 320 ms | none | already visible |
| Route | Navigation | Fade | move 260 ms | none | instant |
| Save | Backend accepts write | Visible success message | quick | light commit | same message |
| Validation | Invalid input/error | Inline message | instant | none | same message |

No animation blocks input or loops. Reveals settle immediately on a tap. A single persisted setting gates haptics; a reduce-motion setting augments the OS preference. Network progress uses text for accessibility.
