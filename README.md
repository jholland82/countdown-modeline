# countdown-modeline

Display a color-coded countdown (in days) to upcoming events in your Emacs modeline. The soonest upcoming event is shown; past events are skipped automatically. The countdown refreshes itself at local midnight via an internal timer — no `midnight-mode` setup required.

The text color changes as the event approaches:

- **Green** — 10+ days remaining
- **Yellow** — 5–9 days remaining
- **Red** — fewer than 5 days remaining

Works with both the default Emacs modeline and [doom-modeline](https://github.com/seagle0128/doom-modeline).

## Installation

### use-package with vc (Emacs 30+)

```elisp
(use-package countdown-modeline
  :vc (:url "https://github.com/jholland82/countdown-modeline" :rev :newest)
  :config
  (setq countdown-modeline-events
        '(("Launch Day"     "2026-12-25" "🚀")
          ("Vacation"       "2026-07-01" "🏖️")
          ("Standup"        "2026-05-10")
          ("Mom's Birthday" "1955-06-15" "🎂" t) ; t = anniversary
          ("Wedding"        "06-15"      "💍" t)))
  (countdown-modeline-mode 1))
```

### straight.el

```elisp
(use-package countdown-modeline
  :straight (:host github :repo "jholland82/countdown-modeline")
  :config
  (setq countdown-modeline-events
        '(("Launch Day"     "2026-12-25" "🚀")
          ("Vacation"       "2026-07-01" "🏖️")
          ("Standup"        "2026-05-10")
          ("Mom's Birthday" "1955-06-15" "🎂" t) ; t = anniversary
          ("Wedding"        "06-15"      "💍" t)))
  (countdown-modeline-mode 1))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/countdown-modeline")
(require 'countdown-modeline)
(setq countdown-modeline-events
      '(("Launch Day"     "2026-12-25" "🚀")
        ("Vacation"       "2026-07-01" "🏖️")
        ("Standup"        "2026-05-10")
        ("Mom's Birthday" "1955-06-15" "🎂" t) ; t = anniversary
        ("Wedding"        "06-15"      "💍" t)))
(countdown-modeline-mode 1)
```

## Configuration

Each entry in `countdown-modeline-events` is a list `(NAME DATE &optional PREFIX ANNIVERSARY-P)`:

- **NAME** — display name shown in the modeline.
- **DATE** — target date in `YYYY-MM-DD` format, or `MM-DD` for a yearless anniversary.
- **PREFIX** — optional string shown before the name. Typically an emoji, but any string works (omit or use `nil` for none).
- **ANNIVERSARY-P** — when non-nil, marks the event as recurring. The countdown then advances to the next annual occurrence of DATE rather than expiring after the date passes. A yearless `MM-DD` date is only valid when this flag is set.

If you change `countdown-modeline-events` via `setq` after the mode is enabled, run `M-x countdown-modeline-refresh` (or use `customize-set-variable` / `setopt`, which refresh automatically).

By default, the soonest upcoming event is shown. To pin a specific upcoming event instead, use `M-x countdown-modeline-pin-event`. If the pinned event passes its date or is removed, the display silently falls back to the soonest upcoming event until you pick a new one. Clear the pin with `M-x countdown-modeline-unpin-event`.

`M-x countdown-modeline-pin-event` only sets the pin for the current session. To persist it across restarts, save the `countdown-modeline-pinned-event` defcustom via `M-x customize-save-variable`, or set it in your init file with `setopt`.

### Anniversaries

An anniversary is a recurring event — birthdays, wedding anniversaries, memorial dates, holidays, anything that repeats annually. Unlike one-time events, anniversaries don't expire: once this year's occurrence has passed, the countdown rolls over to next year's. This also means anniversaries are always eligible for pinning, even when the stored date itself is in the past.

You can specify an anniversary's date two ways:

- **Full `YYYY-MM-DD`** — preserves the original year. Use this for birthdays (the birth year), wedding anniversaries (the wedding year), or memorial dates. The countdown ignores the year for "days until" but the year is kept in storage so you can compute age, years married, etc. yourself.
- **Yearless `MM-DD`** — for anniversaries whose original year is unknown, irrelevant, or you simply don't want to record. Yearless dates are only valid when the anniversary flag is set.

Feb 29 anniversaries fall back to Feb 28 in non-leap years.

To add an anniversary interactively, `M-x countdown-modeline-add-event` and enter either a past full date or a yearless `MM-DD`. You'll be prompted to confirm whether the entry is an anniversary. Declining on a yearless date is rejected as an invalid event (yearless non-anniversaries have no meaning).

Programmatically:

```elisp
(countdown-modeline-add-event "Mom's Birthday" "1955-06-15" "🎂" t)
(countdown-modeline-add-event "Wedding"        "06-15"      "💍" t)
```

### Interactive commands

| Command | Description |
|---|---|
| `M-x countdown-modeline-add-event` | Add or update an event. Offers completion over existing names; empty RET on the date or prefix prompt keeps the existing value when updating. A yearless or past date triggers a y/n prompt asking whether the entry is an anniversary; declining on a yearless date is rejected. |
| `M-x countdown-modeline-remove-event` | Remove an event by name (with completion). |
| `M-x countdown-modeline-list-events` | Show all events in a help buffer, sorted by days remaining (soonest first; past events at the bottom). Anniversary entries are annotated. |
| `M-x countdown-modeline-pin-event` | Pin a specific event to the modeline display. Completion is offered over upcoming-or-today events only, sorted soonest first and annotated with each event's date and days remaining. The soonest upcoming event (or your current pin, if it is still upcoming) is the default — press RET to accept it, or use TAB / your completion UI's navigation to choose another. |
| `M-x countdown-modeline-unpin-event` | Clear the pin and revert to showing the soonest upcoming event. |
| `M-x countdown-modeline-count-upcoming-events` | Display the number of upcoming events (past and invalid-date events are skipped). |
| `M-x countdown-modeline-count-past-events` | Display the number of past events (upcoming and invalid-date events are skipped). |
| `M-x countdown-modeline-count-all-events` | Display the total number of events configured, including past and invalid-date entries. |
| `M-x countdown-modeline-refresh` | Recompute the modeline string. Useful after `setq`. |
| `M-x countdown-modeline-save-events` | Write current events to `countdown-modeline-events-file`. |
| `M-x countdown-modeline-load-events` | Read events from `countdown-modeline-events-file`. The file is validated before its contents replace the current list. |

### Persisting events

`countdown-modeline-events-file` (default `~/.emacs.d/countdown-modeline-events.eld`) holds a single Lisp form and is safe to hand-edit:

```elisp
;;; countdown-modeline events.  Auto-generated; safe to edit.
(:format-version 2
 :events (("Launch Day"     "2026-12-25" "🚀")
          ("Vacation"       "2026-07-01" "🏖️")
          ("Standup"        "2026-05-10")
          ("Mom's Birthday" "1955-06-15" "🎂" t)
          ("Wedding"        "06-15"      "💍" t)))
```

Files written by older versions of this package (format version 1, or a bare events list with no envelope at all) are accepted on load and upgraded to the current format on the next save. Files written by a newer version than the installed package are rejected with a clear error rather than loaded as garbage.

Events added interactively live only in memory until you `M-x countdown-modeline-save-events`. To restore them in a later session:

```elisp
(countdown-modeline-load-events)
(countdown-modeline-mode 1)
```

Set `countdown-modeline-save-events-on-change` to `t` to persist automatically after every add or remove (whether made interactively or programmatically). If a save fails (e.g. the disk is full), the in-memory change still succeeds and a warning is logged — call `M-x countdown-modeline-save-events` to retry.

### Customizing colors

Each face has separate defaults for light and dark backgrounds, and falls back to the built-in `success`, `warning`, and `error` faces on low-color terminals. Customize via `M-x customize-face`:

| Face | Days | Light bg | Dark bg |
|---|---|---|---|
| `countdown-modeline-green` | 10+ | `#1d7a1d` | `#51cf66` |
| `countdown-modeline-yellow` | 5–9 | `#946a00` | `#fcc419` |
| `countdown-modeline-red` | < 5 | `#c92a2a` | `#ff6b6b` |

## License

GPL-3.0-or-later
