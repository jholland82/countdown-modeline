# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-05-07 [Released]

### Added

- `countdown-modeline-pinned-event` defcustom and the commands `countdown-modeline-pin-event` / `countdown-modeline-unpin-event` let you override the auto-soonest selection and pin a specific upcoming event for the modeline. Completion is offered over upcoming-or-today events only, sorted soonest-first and annotated with each event's prefix, date, and days remaining (columns aligned across candidates). The current pin (or, when none is set, the soonest upcoming event) is the default — an empty RET accepts it; use TAB or your completion UI's navigation keys to choose another. A stale pin (event removed or passed) silently falls back to the soonest upcoming event. Per Customize semantics, the pin is per-session unless saved via `M-x customize-save-variable` or set in your init file with `setopt` / `customize-set-variable`.

## [1.1.0] - 2026-05-06 [Released]

### Added

- `countdown-modeline-count-upcoming-events` returns the number of upcoming events (today counts as upcoming; past and invalid-date events are skipped).
- `countdown-modeline-count-past-events` returns the number of past events (today is not past; invalid-date events are skipped).
- `countdown-modeline-count-all-events` returns the total event count, including past and invalid-date entries.
- All three commands message the count with proper pluralization when called interactively, and return the integer for use in Lisp.

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

[Unreleased]: https://github.com/jholland82/countdown-modeline/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/jholland82/countdown-modeline/releases/tag/v1.2.0
[1.1.0]: https://github.com/jholland82/countdown-modeline/releases/tag/v1.1.0
[1.0.1]: https://github.com/jholland82/countdown-modeline/releases/tag/v1.0.1
[1.0.0]: https://github.com/jholland82/countdown-modeline/releases/tag/v1.0.0
