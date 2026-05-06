;;; countdown-modeline.el --- Display a color-coded countdown in the modeline -*- lexical-binding: t -*-

;; Author: Jeffrey Holland <jeff.holland@gmail.com>
;; Maintainer: Jeffrey Holland <jeff.holland@gmail.com>
;; Version: 1.1.0
;; URL: https://github.com/jholland82/countdown-modeline
;; Keywords: convenience, modeline
;; Package-Requires: ((emacs "27.1"))
;; SPDX-License-Identifier: GPL-3.0-or-later

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

;; countdown-modeline displays the soonest upcoming event from
;; `countdown-modeline-events' as a day countdown in the Emacs modeline.
;; Past events are skipped automatically, and the countdown refreshes at
;; local midnight via an internal timer (no external setup required).
;;
;; The text color changes as the event approaches:
;;
;;   - Green  : 10+ days remaining
;;   - Yellow : 5-9 days remaining
;;   - Red    : fewer than 5 days remaining
;;
;; Usage:
;;
;;   (require 'countdown-modeline)
;;   (setq countdown-modeline-events
;;         '(("Launch Day" "2026-12-25" "🚀")
;;           ("Vacation"   "2026-07-01" "🏖️")
;;           ("Standup"    "2026-05-10")))    ; emoji is optional
;;   (countdown-modeline-mode 1)
;;
;; Run M-x countdown-modeline-list-events to discover the available
;; commands.  Works with doom-modeline and the default modeline.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'time-date)
(require 'subr-x)

(defgroup countdown-modeline nil
  "Display days until an event in the modeline."
  :group 'mode-line)

(defcustom countdown-modeline-events nil
  "List of events to count down to.
Each entry is a list (NAME DATE &optional PREFIX):
  - NAME is the event's display name.
  - DATE is a string in YYYY-MM-DD format.
  - PREFIX is an optional string (typically an emoji) shown
    before the name.

The soonest upcoming event is shown in the modeline; past events
are skipped.

Example:
  (setq countdown-modeline-events
        \\='((\"Launch Day\" \"2026-12-25\" \"🚀\")
          (\"Vacation\"   \"2026-07-01\" \"🏖️\")
          (\"Standup\"    \"2026-05-10\")))"
  :type '(alist :key-type (string :tag "Name")
                :value-type
                (list (string :tag "Date (YYYY-MM-DD)")
                      (choice (const :tag "None" nil)
                              (string :tag "Prefix"))))
  :set (lambda (sym val)
         (set-default sym val)
         (when (bound-and-true-p countdown-modeline-mode)
           (countdown-modeline--update)))
  :group 'countdown-modeline)

(defcustom countdown-modeline-events-file
  (locate-user-emacs-file "countdown-modeline-events.eld")
  "File used to persist `countdown-modeline-events'.
`countdown-modeline-save-events' writes the current value here, and
`countdown-modeline-load-events' reads it back.  The file holds a
single Lisp form, safe to edit by hand:

  ;;; countdown-modeline events.  Auto-generated; safe to edit.
  (:format-version 1
   :events ((\"Launch Day\" \"2026-12-25\" \"🚀\")
            (\"Vacation\"   \"2026-07-01\" \"🏖️\")
            (\"Standup\"    \"2026-05-10\")))

For backward compatibility, files containing only a bare events
list (no envelope) are also accepted on load."
  :type 'file
  :group 'countdown-modeline)

(defcustom countdown-modeline-save-events-on-change nil
  "If non-nil, write events to disk after every add or remove.
Applies whether the change is made interactively or programmatically.
When nil (the default), call `countdown-modeline-save-events'
explicitly to persist changes."
  :type 'boolean
  :group 'countdown-modeline)

(defface countdown-modeline-green
  '((((class color) (min-colors 88) (background light))
     :foreground "#1d7a1d")
    (((class color) (min-colors 88) (background dark))
     :foreground "#51cf66")
    (t :inherit success))
  "Face for countdown when more than 10 days remain."
  :group 'countdown-modeline)

(defface countdown-modeline-yellow
  '((((class color) (min-colors 88) (background light))
     :foreground "#946a00")
    (((class color) (min-colors 88) (background dark))
     :foreground "#fcc419")
    (t :inherit warning))
  "Face for countdown when 5-9 days remain."
  :group 'countdown-modeline)

(defface countdown-modeline-red
  '((((class color) (min-colors 88) (background light))
     :foreground "#c92a2a")
    (((class color) (min-colors 88) (background dark))
     :foreground "#ff6b6b")
    (t :inherit error))
  "Face for countdown when fewer than 5 days remain."
  :group 'countdown-modeline)

(defvar countdown-modeline--string nil
  "Current modeline string.")

(defvar countdown-modeline--timer nil
  "Timer that refreshes the countdown at the next local midnight.")

(defconst countdown-modeline--save-format-version 1
  "Current version of the persisted events file format.
Files written by `countdown-modeline-save-events' carry this version.
`countdown-modeline-load-events' rejects files whose version is
greater than this number.")

(defun countdown-modeline--today ()
  "Return today's absolute day number in local time."
  (time-to-days (current-time)))

(defun countdown-modeline--parse-date (date)
  "Return the absolute day number for DATE, or nil if DATE is invalid.
DATE is a string in YYYY-MM-DD format.  Validation is both syntactic
and semantic: \"2026-13-45\" is rejected by round-tripping through
`encode-time'."
  (when (and (stringp date)
             (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'" date))
    (let* ((year    (string-to-number (substring date 0 4)))
           (month   (string-to-number (substring date 5 7)))
           (day     (string-to-number (substring date 8 10)))
           (encoded (encode-time 0 0 0 day month year)))
      (when (equal date (format-time-string "%Y-%m-%d" encoded))
        (time-to-days encoded)))))

(defun countdown-modeline--days-until (date)
  "Return days from today until DATE, or nil if DATE is invalid.
The result may be negative for past dates."
  (let ((target (countdown-modeline--parse-date date)))
    (when target (- target (countdown-modeline--today)))))

(defun countdown-modeline--next-event ()
  "Return (NAME DAYS PREFIX) for the soonest upcoming event, or nil.
PREFIX is nil when the event has no prefix string.  Events with
invalid or past dates are skipped."
  (let ((today (countdown-modeline--today))
        next)
    (dolist (event countdown-modeline-events)
      (pcase-let ((`(,name ,date ,prefix) event))
        (let ((target (countdown-modeline--parse-date date)))
          (when target
            (let ((days (- target today)))
              (when (and (>= days 0)
                         (or (null next) (< days (cadr next))))
                (setq next (list name days prefix))))))))
    next))

(defun countdown-modeline--valid-events-p (events)
  "Return non-nil if EVENTS is a well-formed events list.
A well-formed list contains entries of the form (NAME DATE) or
\(NAME DATE PREFIX) where each present element is a string (PREFIX
may also be nil)."
  (and (listp events)
       (seq-every-p
        (lambda (e)
          (and (listp e)
               (<= 2 (length e) 3)
               (stringp (nth 0 e))
               (stringp (nth 1 e))
               (or (null (nth 2 e)) (stringp (nth 2 e)))))
        events)))

(defun countdown-modeline--extract-events (form)
  "Return the validated events list contained in FORM.
FORM is the value `read' from `countdown-modeline-events-file'.
Two shapes are recognized:

  - A bare events list (legacy/unversioned), treated as
    `countdown-modeline--save-format-version' = 1.
  - A versioned plist of the shape
    \(:format-version N :events EVENTS).

Signals `user-error' if FORM is unrecognized, the version is
newer than this build supports, or :events is malformed."
  (let ((events
         (cond
          ;; Legacy bare events list.
          ((countdown-modeline--valid-events-p form) form)
          ;; Versioned plist envelope.
          ((and (listp form) (keywordp (car-safe form)))
           (let ((version (plist-get form :format-version)))
             (unless (integerp version)
               (user-error "Missing or invalid :format-version"))
             (when (> version countdown-modeline--save-format-version)
               (user-error
                "File format version %d is newer than supported (%d)"
                version countdown-modeline--save-format-version))
             (unless (plist-member form :events)
               (user-error "File envelope is missing the :events key"))
             (plist-get form :events)))
          (t (user-error "Unrecognized events file format")))))
    (unless (countdown-modeline--valid-events-p events)
      (user-error "Malformed :events list"))
    events))

(defun countdown-modeline--face (days)
  "Return the appropriate face for DAYS remaining."
  (cond
   ((< days 5)  'countdown-modeline-red)
   ((< days 10) 'countdown-modeline-yellow)
   (t           'countdown-modeline-green)))

(defun countdown-modeline--update ()
  "Update the modeline countdown string."
  (let ((next (countdown-modeline--next-event)))
    (setq countdown-modeline--string
          (if next
              (pcase-let* ((`(,name ,days ,prefix) next)
                           (face (countdown-modeline--face days)))
                (propertize (format " %s%s %d Day%s "
                                    (if prefix (concat prefix " ") "")
                                    name
                                    days
                                    (if (= days 1) "" "s"))
                            'face face))
            ""))
    (force-mode-line-update)))

(defun countdown-modeline--schedule-midnight ()
  "(Re)schedule a timer to refresh the countdown at the next local midnight.
The timer's handler also reschedules itself, so the countdown keeps
refreshing every day for as long as `countdown-modeline-mode' is on."
  (when (timerp countdown-modeline--timer)
    (cancel-timer countdown-modeline--timer))
  (let* ((d (decode-time))
         ;; encode-time normalizes day overflow, so day+1 handles month
         ;; and year boundaries.
         (next-midnight (encode-time 0 0 0
                                     (1+ (decoded-time-day d))
                                     (decoded-time-month d)
                                     (decoded-time-year d))))
    (setq countdown-modeline--timer
          (run-at-time next-midnight nil
                       #'countdown-modeline--midnight-tick))))

(defvar countdown-modeline-mode)

(defun countdown-modeline--midnight-tick ()
  "Refresh the countdown and reschedule the next midnight tick.
No-ops if `countdown-modeline-mode' was disabled between scheduling
and firing."
  (when countdown-modeline-mode
    (countdown-modeline--update)
    (countdown-modeline--schedule-midnight)))

;;;###autoload
(defun countdown-modeline-refresh ()
  "Recompute the modeline countdown string.
Call this after setting `countdown-modeline-events' with `setq'.
Not needed when the variable is changed via `customize' or `setopt',
or via `countdown-modeline-add-event'/`-remove-event'/`-load-events'."
  (interactive)
  (countdown-modeline--update))

;;;###autoload
(defun countdown-modeline-add-event (name date &optional prefix)
  "Add an event with NAME, DATE (YYYY-MM-DD), and optional PREFIX.
PREFIX is a string (typically an emoji) shown before the name; an
empty string is treated as nil.  If an event with the same NAME
already exists, it is updated.

Signals a `user-error' when NAME is empty or DATE is not a valid
YYYY-MM-DD calendar date.

Interactively, completion is offered over existing names; an empty
RET on the date or prefix prompt accepts the existing value when
updating."
  (interactive
   (let* ((existing-names (mapcar #'car countdown-modeline-events))
          (name (completing-read "Event name: " existing-names nil nil))
          (existing (cdr (assoc name countdown-modeline-events)))
          (default-date (or (car existing) ""))
          (default-prefix (or (cadr existing) ""))
          (date (read-string
                 (format "Event date (YYYY-MM-DD)%s: "
                         (if (string-blank-p default-date) ""
                           (format " (default %s)" default-date)))
                 nil nil default-date))
          (raw-prefix (read-string
                       (format "Prefix, e.g. emoji (RET to %s): "
                               (if (string-blank-p default-prefix)
                                   "skip"
                                 (format "keep %s" default-prefix)))
                       nil nil default-prefix)))
     (list name date (and (not (string-blank-p raw-prefix)) raw-prefix))))
  (when (or (not (stringp name)) (string-blank-p name))
    (user-error "Event name must be a non-empty string"))
  (unless (countdown-modeline--parse-date date)
    (user-error "Invalid event date %S (expected YYYY-MM-DD)" date))
  (when (and prefix (string-blank-p prefix))
    (setq prefix nil))
  (setf (alist-get name countdown-modeline-events nil nil #'equal)
        (if prefix (list date prefix) (list date)))
  (countdown-modeline--update)
  (countdown-modeline--maybe-auto-save))

;;;###autoload
(defun countdown-modeline-remove-event (name)
  "Remove the event with NAME from `countdown-modeline-events'."
  (interactive
   (list (completing-read "Remove event: "
                          (mapcar #'car countdown-modeline-events)
                          nil t)))
  (setf (alist-get name countdown-modeline-events nil t #'equal) nil)
  (countdown-modeline--update)
  (countdown-modeline--maybe-auto-save))

(defun countdown-modeline--maybe-auto-save ()
  "Save events to disk if `countdown-modeline-save-events-on-change' is on.
A failed save is reported as a warning rather than a signaled error,
so the in-memory change (which already succeeded) is not surfaced as
data loss to callers."
  (when countdown-modeline-save-events-on-change
    (condition-case err
        (countdown-modeline-save-events)
      (error
       (display-warning 'countdown-modeline
                        (format "Auto-save failed: %s.  In-memory \
events changed; call `countdown-modeline-save-events' to retry."
                                (error-message-string err))
                        :warning)))))

(defun countdown-modeline--sort-key (days)
  "Return a (GROUP . SUB) sort key for DAYS remaining.
GROUP orders future before past before invalid; SUB orders within
each group: future ascending (soonest first), past by recency
\(most recent first)."
  (cond
   ((null days)  (cons 2 0))
   ((>= days 0)  (cons 0 days))
   (t            (cons 1 (- days)))))

(defun countdown-modeline--count-when (predicate)
  "Return the number of events whose days-until result satisfies PREDICATE.
Events with invalid dates have a nil days-until and are never counted."
  (seq-count
   (lambda (event)
     (let ((days (countdown-modeline--days-until (nth 1 event))))
       (and days (funcall predicate days))))
   countdown-modeline-events))

;;;###autoload
(defun countdown-modeline-count-upcoming-events ()
  "Return the number of upcoming events in `countdown-modeline-events'.
Past events and events with invalid dates are not counted.  An
event whose date is today counts as upcoming.

When called interactively, also display the count in the echo area."
  (interactive)
  (let ((count (countdown-modeline--count-when (lambda (d) (>= d 0)))))
    (when (called-interactively-p 'interactive)
      (message "%d upcoming event%s"
               count
               (if (= count 1) "" "s")))
    count))

;;;###autoload
(defun countdown-modeline-count-past-events ()
  "Return the number of past events in `countdown-modeline-events'.
Upcoming events (including today) and events with invalid dates
are not counted.

When called interactively, also display the count in the echo area."
  (interactive)
  (let ((count (countdown-modeline--count-when (lambda (d) (< d 0)))))
    (when (called-interactively-p 'interactive)
      (message "%d past event%s"
               count
               (if (= count 1) "" "s")))
    count))

;;;###autoload
(defun countdown-modeline-count-all-events ()
  "Return the total number of events in `countdown-modeline-events'.
Includes past events and events with invalid dates.

When called interactively, also display the count in the echo area."
  (interactive)
  (let ((count (length countdown-modeline-events)))
    (when (called-interactively-p 'interactive)
      (message "%d event%s configured"
               count
               (if (= count 1) "" "s")))
    count))

;;;###autoload
(defun countdown-modeline-list-events ()
  "Display all configured events with days remaining in a help buffer.
Upcoming events are shown first (soonest at the top), followed by
past events (most recent first) and any with invalid dates."
  (interactive)
  (let ((rows (mapcar (lambda (event)
                        (list (countdown-modeline--days-until (nth 1 event))
                              (nth 0 event)
                              (nth 1 event)
                              (nth 2 event)))
                      countdown-modeline-events)))
    (setq rows (sort rows
                     (lambda (a b)
                       (let ((ka (countdown-modeline--sort-key (car a)))
                             (kb (countdown-modeline--sort-key (car b))))
                         (or (< (car ka) (car kb))
                             (and (= (car ka) (car kb))
                                  (< (cdr ka) (cdr kb))))))))
    (with-help-window "*countdown-modeline events*"
      (with-current-buffer standard-output
        (insert (format "%-6s  %-12s  %s\n" "Days" "Date" "Event"))
        (insert (make-string 50 ?-) "\n")
        (if (null rows)
            (insert "  (no events configured)\n")
          (dolist (row rows)
            (pcase-let ((`(,days ,name ,date ,prefix) row))
              (insert (format "%-6s  %-12s  %s%s\n"
                              (if days (number-to-string days) "?")
                              date
                              (if prefix (concat prefix " ") "")
                              name)))))))))

;;;###autoload
(defun countdown-modeline-save-events ()
  "Save `countdown-modeline-events' to `countdown-modeline-events-file'.
Refuses to write if the in-memory value is malformed, so a corrupt
state cannot clobber a previously valid file.  The parent directory
is created if it does not already exist.

The file is written as a versioned plist envelope so future format
changes can be detected and migrated; legacy bare-list files remain
loadable for backward compatibility."
  (interactive)
  (unless (countdown-modeline--valid-events-p countdown-modeline-events)
    (user-error "Refusing to save: countdown-modeline-events is malformed"))
  (when-let* ((dir (file-name-directory countdown-modeline-events-file)))
    (make-directory dir t))
  (with-temp-file countdown-modeline-events-file
    (insert ";;; countdown-modeline events.  Auto-generated; safe to edit.\n")
    (let ((print-level nil)
          (print-length nil))
      (pp (list :format-version countdown-modeline--save-format-version
                :events countdown-modeline-events)
          (current-buffer))))
  (message "Saved %d event(s) to %s"
           (length countdown-modeline-events)
           countdown-modeline-events-file))

;;;###autoload
(defun countdown-modeline-load-events ()
  "Load events from `countdown-modeline-events-file'.
Replaces the current value of `countdown-modeline-events'.  The
file is validated before its contents are installed; an invalid
file or one written by a newer version of this package leaves the
current events untouched."
  (interactive)
  (unless (file-readable-p countdown-modeline-events-file)
    (user-error "Cannot read %s" countdown-modeline-events-file))
  (let* ((form (with-temp-buffer
                 (insert-file-contents countdown-modeline-events-file)
                 (goto-char (point-min))
                 (read (current-buffer))))
         (events (countdown-modeline--extract-events form)))
    (setq countdown-modeline-events events))
  (countdown-modeline--update)
  (message "Loaded %d event(s) from %s"
           (length countdown-modeline-events)
           countdown-modeline-events-file))

;;;###autoload
(define-minor-mode countdown-modeline-mode
  "Toggle the countdown display in the modeline (a global minor mode).

When enabled, the modeline shows the soonest upcoming event from
`countdown-modeline-events'; past events are skipped.  An internal
timer refreshes the display at the next local midnight, and is
canceled when the mode is disabled.

Add or update events with `countdown-modeline-add-event' and
inspect them with `countdown-modeline-list-events'.  Use
`countdown-modeline-save-events' / -load-events' to persist them
to `countdown-modeline-events-file' across sessions."
  :global t
  (if countdown-modeline-mode
      (progn
        (countdown-modeline--update)
        (countdown-modeline--schedule-midnight)
        (add-to-list 'global-mode-string '(:eval countdown-modeline--string) t))
    (when (timerp countdown-modeline--timer)
      (cancel-timer countdown-modeline--timer)
      (setq countdown-modeline--timer nil))
    (setq global-mode-string
          (delete '(:eval countdown-modeline--string) global-mode-string))
    (setq countdown-modeline--string nil)
    (force-mode-line-update)))

(provide 'countdown-modeline)
;;; countdown-modeline.el ends here
