;;; countdown-modeline.el --- Display a color-coded countdown in the modeline -*- lexical-binding: t -*-

;; Author: Jeffrey Holland
;; Version: 0.1.0
;; URL: https://github.com/jeffreyholland/countdown-modeline
;; Keywords: convenience, modeline
;; Package-Requires: ((emacs "27.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; countdown-modeline displays a countdown (in days) to a specified event
;; in the Emacs modeline.  The text color changes as the event approaches:
;;
;;   - Green  : 10+ days remaining
;;   - Yellow : 5-9 days remaining
;;   - Red    : fewer than 5 days remaining
;;
;; Usage:
;;
;;   (require 'countdown-modeline)
;;   (setq countdown-modeline-event-name "Launch Day"
;;         countdown-modeline-event-date "2026-12-25"
;;         countdown-modeline-emoji "🚀")     ; optional
;;   (countdown-modeline-mode 1)
;;
;; Or configure interactively with M-x countdown-modeline-set-event.
;;
;; Works with doom-modeline and the default modeline.

;;; Code:

(defgroup countdown-modeline nil
  "Display days until an event in the modeline."
  :group 'mode-line
  :prefix "countdown-modeline-")

(defcustom countdown-modeline-event-name "Event"
  "Name of the event to count down to."
  :type 'string
  :group 'countdown-modeline)

(defcustom countdown-modeline-event-date ""
  "Target date in YYYY-MM-DD format."
  :type 'string
  :group 'countdown-modeline)

(defcustom countdown-modeline-emoji nil
  "Optional emoji to display before the countdown.
For example: \"🎉\" or \"🚀\".  Set to nil for no emoji."
  :type '(choice (const :tag "None" nil)
                 (string :tag "Emoji"))
  :group 'countdown-modeline)

(defface countdown-modeline-green
  '((t :inherit unspecified :foreground "#51cf66"))
  "Face for countdown when more than 10 days remain."
  :group 'countdown-modeline)

(defface countdown-modeline-yellow
  '((t :inherit unspecified :foreground "#fcc419"))
  "Face for countdown when 5-10 days remain."
  :group 'countdown-modeline)

(defface countdown-modeline-red
  '((t :inherit unspecified :foreground "#ff6b6b"))
  "Face for countdown when fewer than 5 days remain."
  :group 'countdown-modeline)

(defvar countdown-modeline--string nil
  "Current modeline string.")

(defun countdown-modeline--days-until ()
  "Return the number of days until `countdown-modeline-event-date', or nil."
  (when (and (stringp countdown-modeline-event-date)
             (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'" countdown-modeline-event-date))
    (let* ((target (date-to-day countdown-modeline-event-date))
           (today (date-to-day (format-time-string "%Y-%m-%d")))
           (diff (- target today)))
      (max 0 diff))))

(defun countdown-modeline--face (days)
  "Return the appropriate face for DAYS remaining."
  (cond
   ((< days 5)  'countdown-modeline-red)
   ((< days 10) 'countdown-modeline-yellow)
   (t           'countdown-modeline-green)))

(defun countdown-modeline--update ()
  "Update the modeline countdown string."
  (let ((days (countdown-modeline--days-until)))
    (setq countdown-modeline--string
          (if days
              (let ((face (countdown-modeline--face days)))
                (propertize (format " %s%d Days "
                                   (if countdown-modeline-emoji
                                       (concat countdown-modeline-emoji " ")
                                     "")
                                   days)
                            'face face
                            'font-lock-face face))
            ""))
    (force-mode-line-update t)))

(defun countdown-modeline-set-event (name date)
  "Interactively set the event NAME and DATE (YYYY-MM-DD)."
  (interactive
   (list (read-string "Event name: " countdown-modeline-event-name)
         (read-string "Event date (YYYY-MM-DD): " countdown-modeline-event-date)))
  (setq countdown-modeline-event-name name
        countdown-modeline-event-date date)
  (countdown-modeline--update))

;;;###autoload
(define-minor-mode countdown-modeline-mode
  "Toggle countdown display in the modeline."
  :global t
  :lighter nil
  (if countdown-modeline-mode
      (progn
        (require 'midnight)
        (countdown-modeline--update)
        (add-hook 'midnight-hook #'countdown-modeline--update)
        (add-to-list 'global-mode-string '(:eval countdown-modeline--string) t))
    (remove-hook 'midnight-hook #'countdown-modeline--update)
    (setq global-mode-string
          (delete '(:eval countdown-modeline--string) global-mode-string))
    (setq countdown-modeline--string nil)
    (force-mode-line-update t)))

(provide 'countdown-modeline)
;;; countdown-modeline.el ends here
