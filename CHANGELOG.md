# Changelog

All notable changes to Passed Note are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-07-20

### Added
- **Time Size setting** (Normal / Large / Huge): write the time bigger on the
  page. Sizes are tuned so the centered time still clears the middle punch hole
  on every panel, so all three holes stay. `tools/gen_fonts.py` bakes two extra
  digit-only time fonts per resolution; the face loads only the selected one.

## [1.0.3] - 2026-07-05

### Fixed
- **Legal pad setting reliably applies**: property reads now also accept Long
  values from the settings editor (previously such values were silently
  discarded and the paper stayed white). Note for simulator testing: the sim
  saves chosen settings per app and they override the shipped defaults.

### Changed
- The legal pad is properly **yellow** now (deeper legal-pad tone instead of
  the old pale cream).

## [1.0.2] - 2026-07-05

The layout settles down.

### Changed
- **One thought per line**: below the time everything is centered and grouped
  by category — steps with the pulse doodled beside them, calories, battery
  (with the phone's message count jotted in red beside it), and Body Battery
  on the short last rule. Weather keeps its two lines: doodled icon +
  temperature, condition word underneath.
- Every line now fits its rule at any realistic value — nothing can reach the
  round edge or the punch holes.
- Refreshed the store artwork (icon / cover / hero) to match the final layout.

## [1.0.1] - 2026-07-05

Layout and settings fixes from the first day on the wrist.

### Fixed
- **Calories clipped at the bottom curve**: the data lines below the time moved
  up one rule, so the last line no longer sits where the round screen is too
  narrow for a real calorie count.
- **Battery overlapping the bottom punch hole**: the battery line now starts at
  the red margin instead of being centered into the hole.
- **Body Battery clipped at the right edge**: "energy" moved down beside the
  calories, centered on a wide rule; the notification count got the narrow
  last rule to itself.
- **Settings robustness**: property reads now tolerate numbers arriving as
  strings/booleans from the settings editor (paper style / time pen could
  fail to apply).

## [1.0.0] - 2026-07-05

Initial release. 📝

### Added
- Lined notebook filler paper drawn procedurally — light-blue rules, red margin
  line, and punch holes hugging the left curve of the screen.
- Four handwriting fonts (Segoe Script, Segoe Script Bold, Segoe Print Bold,
  Ink Free) baked into per-resolution bitmap font sets by `tools/gen_fonts.py`,
  with every line of writing sitting on the notebook rules.
- The date in neat black printing; the time written huge in loopy script with a
  squiggle underline.
- Doodled dynamic weather between the date and the time: a pen-sketch icon that
  matches the live conditions (sun / partly / cloud / rain / snow / storm with
  red lightning), the temperature, and the condition word in blue cursive.
- Steps in black scrawl with the heart rate doodled in red beside a little
  heart; device battery in blue cursive next to Body Battery ("energy: 87%");
  calories and the phone notification count on the last rule.
- Settings: time pen colour (blue / black / red), paper style (white filler
  paper / yellow legal pad), and toggles for the weather block and heart rate.
- Burn-in-safe AMOLED Always-On mode — black page, dim ink time, nudged each
  minute.
- Broad round-watch device support (50+ products across 8 panel resolutions).
