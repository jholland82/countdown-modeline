# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-04-28 [Released]

### Fixed

- Corrected the GitHub repository path in the package's `URL:` header, README installation snippets, and changelog link footers (`jeffreyholland/countdown-modeline` → `jholland82/countdown-modeline`).

## [1.0.0] - 2026-04-28 [Released]

Initial release.

### Added

- `countdown-modeline-mode` global minor mode that shows the soonest upcoming event from `countdown-modeline-events` in the modeline.
- `countdown-modeline-events` defcustom: a list of `(NAME DATE &optional PREFIX)` entries. Past events are skipped automatically.
- Color-coded display via three customizable faces (`countdown-modeline-green`, `-yellow`, `-red`) with separate light/dark defaults and `success`/`warning`/`error` fallbacks for low-color terminals.
- Self-rescheduling internal timer that refreshes the display at local midnight; no external setup required.
- Interactive commands: `countdown-modeline-add-event`, `-remove-event`, `-list-events`, `-refresh`, `-save-events`, `-load-events`.
- Versioned persistence to `countdown-modeline-events-file` (defaults to `~/.emacs.d/countdown-modeline-events.eld`); legacy bare-list files load and are upgraded on next save.
- `countdown-modeline-save-events-on-change` defcustom for automatic persistence after every add or remove. Save failures surface as a warning rather than an error.

[Unreleased]: https://github.com/jholland82/countdown-modeline/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/jholland82/countdown-modeline/releases/tag/v1.0.1
[1.0.0]: https://github.com/jholland82/countdown-modeline/releases/tag/v1.0.0
