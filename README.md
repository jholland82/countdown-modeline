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
        '(("Launch Day" "2026-12-25" "🚀")
          ("Vacation"   "2026-07-01" "🏖️")
          ("Standup"    "2026-05-10")))
  (countdown-modeline-mode 1))
```

### straight.el

```elisp
(use-package countdown-modeline
  :straight (:host github :repo "jholland82/countdown-modeline")
  :config
  (setq countdown-modeline-events
        '(("Launch Day" "2026-12-25" "🚀")
          ("Vacation"   "2026-07-01" "🏖️")
          ("Standup"    "2026-05-10")))
  (countdown-modeline-mode 1))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/countdown-modeline")
(require 'countdown-modeline)
(setq countdown-modeline-events
      '(("Launch Day" "2026-12-25" "🚀")
        ("Vacation"   "2026-07-01" "🏖️")
        ("Standup"    "2026-05-10")))
(countdown-modeline-mode 1)
```

## Configuration

Each entry in `countdown-modeline-events` is a list `(NAME DATE &optional PREFIX)`:

- **NAME** — display name shown in the modeline.
- **DATE** — target date in `YYYY-MM-DD` format.
- **PREFIX** — optional string shown before the name. Typically an emoji, but any string works (omit or use `nil` for none).

If you change `countdown-modeline-events` via `setq` after the mode is enabled, run `M-x countdown-modeline-refresh` (or use `customize-set-variable` / `setopt`, which refresh automatically).

### Interactive commands

| Command | Description |
|---|---|
| `M-x countdown-modeline-add-event` | Add or update an event. Offers completion over existing names; empty RET on the date or prefix prompt keeps the existing value when updating. |
| `M-x countdown-modeline-remove-event` | Remove an event by name (with completion). |
| `M-x countdown-modeline-list-events` | Show all events in a help buffer, sorted by days remaining (soonest first; past events at the bottom). |
| `M-x countdown-modeline-refresh` | Recompute the modeline string. Useful after `setq`. |
| `M-x countdown-modeline-save-events` | Write current events to `countdown-modeline-events-file`. |
| `M-x countdown-modeline-load-events` | Read events from `countdown-modeline-events-file`. The file is validated before its contents replace the current list. |

### Persisting events

`countdown-modeline-events-file` (default `~/.emacs.d/countdown-modeline-events.eld`) holds a single Lisp form and is safe to hand-edit:

```elisp
;;; countdown-modeline events.  Auto-generated; safe to edit.
(:format-version 1
 :events (("Launch Day" "2026-12-25" "🚀")
          ("Vacation"   "2026-07-01" "🏖️")
          ("Standup"    "2026-05-10")))
```

Files written by older versions of this package (a bare events list with no envelope) are also accepted on load and are upgraded to the versioned form on the next save.

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
