# countdown-modeline

Display a color-coded countdown (in days) to an event in your Emacs modeline.

The text color changes as the event approaches:

- **Green** — 10+ days remaining
- **Yellow** — 5–9 days remaining
- **Red** — fewer than 5 days remaining

Works with both the default Emacs modeline and [doom-modeline](https://github.com/seagle0128/doom-modeline).

## Installation

### use-package with vc (Emacs 30+)

```elisp
(use-package countdown-modeline
  :vc (:url "https://github.com/jeffreyholland/countdown-modeline" :rev :newest)
  :config
  (setq countdown-modeline-event-name "Launch Day"
        countdown-modeline-event-date "2026-12-25"
        countdown-modeline-emoji "🚀")
  (countdown-modeline-mode 1))
```

### straight.el

```elisp
(use-package countdown-modeline
  :straight (:host github :repo "jeffreyholland/countdown-modeline")
  :config
  (setq countdown-modeline-event-name "Launch Day"
        countdown-modeline-event-date "2026-12-25"
        countdown-modeline-emoji "🚀")
  (countdown-modeline-mode 1))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/countdown-modeline")
(require 'countdown-modeline)
(setq countdown-modeline-event-name "Launch Day"
      countdown-modeline-event-date "2026-12-25"
      countdown-modeline-emoji "🚀")
(countdown-modeline-mode 1)
```

## Configuration

| Variable | Description | Default |
|---|---|---|
| `countdown-modeline-event-name` | Name of the event | `"Event"` |
| `countdown-modeline-event-date` | Target date (YYYY-MM-DD) | `""` |
| `countdown-modeline-emoji` | Optional emoji prefix | `nil` |

You can also set the event interactively with `M-x countdown-modeline-set-event`.

### Customizing colors

The countdown faces can be customized via `M-x customize-face`:

- `countdown-modeline-green` — 10+ days (default `#51cf66`)
- `countdown-modeline-yellow` — 5–9 days (default `#fcc419`)
- `countdown-modeline-red` — under 5 days (default `#ff6b6b`)

## License

GPL-3.0-or-later
