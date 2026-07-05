# Changelog

All notable changes to Passed Note are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
