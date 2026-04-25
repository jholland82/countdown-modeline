;;; countdown-modeline-tests.el --- Tests for countdown-modeline -*- lexical-binding: t -*-

;;; Commentary:

;; Run with: emacs -Q --batch -L . -l countdown-modeline-tests.el \
;;                       -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'countdown-modeline)

(defun countdown-modeline-tests--offset-date (n)
  "Return a YYYY-MM-DD string for N days from today (negative = past)."
  (format-time-string "%Y-%m-%d" (time-add (current-time) (days-to-time n))))

;; --parse-date

(ert-deftest countdown-modeline-test-parse-date-valid ()
  (should (integerp (countdown-modeline--parse-date "2026-12-25"))))

(ert-deftest countdown-modeline-test-parse-date-bad-format ()
  (should-not (countdown-modeline--parse-date "12/25/2026"))
  (should-not (countdown-modeline--parse-date "2026-1-1"))
  (should-not (countdown-modeline--parse-date ""))
  (should-not (countdown-modeline--parse-date nil))
  (should-not (countdown-modeline--parse-date 42)))

(ert-deftest countdown-modeline-test-parse-date-bad-semantics ()
  ;; Month 13 and day 45 pass the regex but should be rejected.
  (should-not (countdown-modeline--parse-date "2026-13-45"))
  (should-not (countdown-modeline--parse-date "2026-02-30"))
  (should-not (countdown-modeline--parse-date "2025-02-29"))
  ;; Leap-year February 29 is valid.
  (should (integerp (countdown-modeline--parse-date "2024-02-29"))))

;; --days-until

(ert-deftest countdown-modeline-test-days-until-today ()
  (should (= 0 (countdown-modeline--days-until
                (countdown-modeline-tests--offset-date 0)))))

(ert-deftest countdown-modeline-test-days-until-future ()
  (should (= 7 (countdown-modeline--days-until
                (countdown-modeline-tests--offset-date 7)))))

(ert-deftest countdown-modeline-test-days-until-past ()
  (should (= -3 (countdown-modeline--days-until
                 (countdown-modeline-tests--offset-date -3)))))

(ert-deftest countdown-modeline-test-days-until-invalid ()
  (should-not (countdown-modeline--days-until "garbage")))

;; --next-event

(ert-deftest countdown-modeline-test-next-event-empty ()
  (let ((countdown-modeline-events nil))
    (should-not (countdown-modeline--next-event))))

(ert-deftest countdown-modeline-test-next-event-all-past ()
  (let ((countdown-modeline-events
         (list (list "Old" (countdown-modeline-tests--offset-date -10)))))
    (should-not (countdown-modeline--next-event))))

(ert-deftest countdown-modeline-test-next-event-picks-soonest ()
  (let ((countdown-modeline-events
         (list (list "Late"  (countdown-modeline-tests--offset-date 30) "L")
               (list "Past"  (countdown-modeline-tests--offset-date -5) "P")
               (list "Soon"  (countdown-modeline-tests--offset-date 3)  "S")
               (list "Plain" (countdown-modeline-tests--offset-date 10)))))
    (should (equal (countdown-modeline--next-event) '("Soon" 3 "S")))))

(ert-deftest countdown-modeline-test-next-event-skips-invalid ()
  (let ((countdown-modeline-events
         (list (list "Bad"  "not-a-date" "B")
               (list "Good" (countdown-modeline-tests--offset-date 5)))))
    (should (equal (countdown-modeline--next-event) '("Good" 5 nil)))))

(ert-deftest countdown-modeline-test-next-event-today-counts-as-upcoming ()
  (let ((countdown-modeline-events
         (list (list "Today" (countdown-modeline-tests--offset-date 0)))))
    (should (equal (countdown-modeline--next-event) '("Today" 0 nil)))))

;; --face thresholds

(ert-deftest countdown-modeline-test-face-thresholds ()
  (should (eq 'countdown-modeline-red    (countdown-modeline--face 0)))
  (should (eq 'countdown-modeline-red    (countdown-modeline--face 4)))
  (should (eq 'countdown-modeline-yellow (countdown-modeline--face 5)))
  (should (eq 'countdown-modeline-yellow (countdown-modeline--face 9)))
  (should (eq 'countdown-modeline-green  (countdown-modeline--face 10)))
  (should (eq 'countdown-modeline-green  (countdown-modeline--face 100))))

;; --update

(ert-deftest countdown-modeline-test-update-no-events ()
  (let ((countdown-modeline-events nil))
    (countdown-modeline--update)
    (should (equal countdown-modeline--string ""))))

(ert-deftest countdown-modeline-test-update-with-prefix ()
  (let ((countdown-modeline-events
         (list (list "Launch" (countdown-modeline-tests--offset-date 7) "🚀"))))
    (countdown-modeline--update)
    (should (equal (substring-no-properties countdown-modeline--string)
                   " 🚀 Launch 7 Days "))))

(ert-deftest countdown-modeline-test-update-without-prefix ()
  (let ((countdown-modeline-events
         (list (list "Standup" (countdown-modeline-tests--offset-date 7)))))
    (countdown-modeline--update)
    (should (equal (substring-no-properties countdown-modeline--string)
                   " Standup 7 Days "))))

(ert-deftest countdown-modeline-test-update-singular-day ()
  "Tomorrow should render as \"1 Day\" (not \"1 Days\")."
  (let ((countdown-modeline-events
         (list (list "Soon" (countdown-modeline-tests--offset-date 1)))))
    (countdown-modeline--update)
    (should (equal (substring-no-properties countdown-modeline--string)
                   " Soon 1 Day "))))

(ert-deftest countdown-modeline-test-update-zero-days-plural ()
  "Today should render as \"0 Days\" (plural for non-1 counts)."
  (let ((countdown-modeline-events
         (list (list "Today" (countdown-modeline-tests--offset-date 0)))))
    (countdown-modeline--update)
    (should (equal (substring-no-properties countdown-modeline--string)
                   " Today 0 Days "))))

;; --valid-events-p

(ert-deftest countdown-modeline-test-valid-events-shapes ()
  (should     (countdown-modeline--valid-events-p nil))
  (should     (countdown-modeline--valid-events-p '(("A" "2026-01-01"))))
  (should     (countdown-modeline--valid-events-p '(("A" "2026-01-01" "🚀"))))
  (should     (countdown-modeline--valid-events-p '(("A" "2026-01-01" nil))))
  (should-not (countdown-modeline--valid-events-p "not a list"))
  (should-not (countdown-modeline--valid-events-p '(("A"))))
  (should-not (countdown-modeline--valid-events-p '(("A" 2026))))
  (should-not (countdown-modeline--valid-events-p '(("A" "d" "p" "extra"))))
  (should-not (countdown-modeline--valid-events-p '((nil "2026-01-01")))))

;; add-event / remove-event

(ert-deftest countdown-modeline-test-add-event-insert ()
  (let ((countdown-modeline-events nil))
    (countdown-modeline-add-event "X" "2026-01-01" "X")
    (should (equal countdown-modeline-events '(("X" "2026-01-01" "X"))))))

(ert-deftest countdown-modeline-test-add-event-update-existing ()
  (let ((countdown-modeline-events '(("X" "2026-01-01" "old"))))
    (countdown-modeline-add-event "X" "2027-06-15" "new")
    (should (equal countdown-modeline-events '(("X" "2027-06-15" "new"))))))

(ert-deftest countdown-modeline-test-add-event-no-prefix ()
  (let ((countdown-modeline-events nil))
    (countdown-modeline-add-event "X" "2026-01-01")
    (should (equal countdown-modeline-events '(("X" "2026-01-01"))))))

(ert-deftest countdown-modeline-test-add-event-rejects-empty-name ()
  (let ((countdown-modeline-events nil))
    (should-error (countdown-modeline-add-event "" "2026-01-01")
                  :type 'user-error)
    (should (null countdown-modeline-events))))

(ert-deftest countdown-modeline-test-add-event-rejects-bad-date ()
  (let ((countdown-modeline-events nil))
    (should-error (countdown-modeline-add-event "X" "not-a-date")
                  :type 'user-error)
    (should-error (countdown-modeline-add-event "X" "2026-13-45")
                  :type 'user-error)
    (should-error (countdown-modeline-add-event "X" "")
                  :type 'user-error)
    (should (null countdown-modeline-events))))

(ert-deftest countdown-modeline-test-add-event-empty-prefix-stored-as-nil ()
  (let ((countdown-modeline-events nil))
    (countdown-modeline-add-event "X" "2026-01-01" "")
    (should (equal countdown-modeline-events '(("X" "2026-01-01"))))))

(ert-deftest countdown-modeline-test-remove-event ()
  (let ((countdown-modeline-events '(("A" "2026-01-01") ("B" "2026-02-02"))))
    (countdown-modeline-remove-event "A")
    (should (equal countdown-modeline-events '(("B" "2026-02-02"))))))

(ert-deftest countdown-modeline-test-remove-event-missing-is-noop ()
  (let ((countdown-modeline-events '(("A" "2026-01-01"))))
    (countdown-modeline-remove-event "Nope")
    (should (equal countdown-modeline-events '(("A" "2026-01-01"))))))

;; save / load

(ert-deftest countdown-modeline-test-save-load-roundtrip ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events
          '(("A" "2026-01-01" "🚀") ("B" "2026-02-02"))))
    (unwind-protect
        (progn
          (countdown-modeline-save-events)
          (let ((countdown-modeline-events nil))
            (countdown-modeline-load-events)
            (should (equal countdown-modeline-events
                           '(("A" "2026-01-01" "🚀") ("B" "2026-02-02"))))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-save-load-empty ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events nil))
    (unwind-protect
        (progn
          (countdown-modeline-save-events)
          (let ((countdown-modeline-events '(("junk" "2026-01-01"))))
            (countdown-modeline-load-events)
            (should (null countdown-modeline-events))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-rejects-invalid-file ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("Keep" "2026-01-01"))))
    (unwind-protect
        (progn
          (with-temp-file tmp (insert "\"not an events list\""))
          (should-error (countdown-modeline-load-events) :type 'user-error)
          ;; Original events untouched after rejection.
          (should (equal countdown-modeline-events '(("Keep" "2026-01-01")))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-missing-file ()
  (let ((countdown-modeline-events-file "/nonexistent/path/cm.eld"))
    (should-error (countdown-modeline-load-events) :type 'user-error)))

;; mode lifecycle

(ert-deftest countdown-modeline-test-mode-enable-installs-timer-and-modeline ()
  (unwind-protect
      (let ((countdown-modeline-events
             (list (list "X" (countdown-modeline-tests--offset-date 5)))))
        (countdown-modeline-mode 1)
        (should (timerp countdown-modeline--timer))
        (should (member '(:eval countdown-modeline--string) global-mode-string)))
    (countdown-modeline-mode -1)))

(ert-deftest countdown-modeline-test-mode-disable-cleans-up ()
  (let ((countdown-modeline-events
         (list (list "X" (countdown-modeline-tests--offset-date 5)))))
    (unwind-protect
        (progn
          (countdown-modeline-mode 1)
          (countdown-modeline-mode -1)
          (should (null countdown-modeline--timer))
          (should (null countdown-modeline--string))
          (should-not (member '(:eval countdown-modeline--string)
                              global-mode-string)))
      ;; Ensure the mode is off even if an assertion failed mid-test.
      (countdown-modeline-mode -1))))

(ert-deftest countdown-modeline-test-refresh-updates-string ()
  (let ((countdown-modeline-events
         (list (list "Z" (countdown-modeline-tests--offset-date 3)))))
    (setq countdown-modeline--string nil)
    (countdown-modeline-refresh)
    (should (string-match-p "Z 3 Days"
                            (substring-no-properties countdown-modeline--string)))))

(ert-deftest countdown-modeline-test-customize-set-refreshes-when-mode-on ()
  (unwind-protect
      (let ((countdown-modeline-events
             (list (list "Old" (countdown-modeline-tests--offset-date 1)))))
        (countdown-modeline-mode 1)
        (customize-set-variable
         'countdown-modeline-events
         (list (list "New" (countdown-modeline-tests--offset-date 8))))
        (should (string-match-p "New 8 Days"
                                (substring-no-properties
                                 countdown-modeline--string))))
    (countdown-modeline-mode -1)
    (setq countdown-modeline-events nil)))

(ert-deftest countdown-modeline-test-auto-save-on-change ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-save-events-on-change t)
         (countdown-modeline-events nil))
    (unwind-protect
        (progn
          (countdown-modeline-add-event "X" "2026-01-01")
          (should (file-exists-p tmp))
          (let ((countdown-modeline-events nil))
            (countdown-modeline-load-events)
            (should (equal countdown-modeline-events
                           '(("X" "2026-01-01"))))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-list-events-renders ()
  (let ((countdown-modeline-events
         (list (list "Soon"  (countdown-modeline-tests--offset-date 3) "S")
               (list "Past"  (countdown-modeline-tests--offset-date -1))
               (list "Plain" (countdown-modeline-tests--offset-date 10)))))
    (save-window-excursion
      (countdown-modeline-list-events)
      (with-current-buffer "*countdown-modeline events*"
        (let ((content (buffer-string)))
          (should (string-match-p "Soon"  content))
          (should (string-match-p "Past"  content))
          (should (string-match-p "Plain" content))
          ;; Soonest upcoming appears before later upcoming.
          (should (< (string-match "Soon" content)
                     (string-match "Plain" content)))
          ;; Past appears after upcoming.
          (should (< (string-match "Plain" content)
                     (string-match "Past" content))))))))

(ert-deftest countdown-modeline-test-list-events-past-ordering ()
  "Past events are ordered most-recent-first, after all upcoming events."
  (let ((countdown-modeline-events
         (list (list "Older"   (countdown-modeline-tests--offset-date -10))
               (list "Recent"  (countdown-modeline-tests--offset-date -2))
               (list "Future"  (countdown-modeline-tests--offset-date 5)))))
    (save-window-excursion
      (countdown-modeline-list-events)
      (with-current-buffer "*countdown-modeline events*"
        (let ((content (buffer-string)))
          (should (< (string-match "Future" content)
                     (string-match "Recent" content)))
          (should (< (string-match "Recent" content)
                     (string-match "Older"  content))))))))

(ert-deftest countdown-modeline-test-save-rejects-malformed ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events 'definitely-not-an-events-list))
    (unwind-protect
        (should-error (countdown-modeline-save-events) :type 'user-error)
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-save-writes-versioned-envelope ()
  "Saved file is a (:format-version N :events …) plist."
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("X" "2026-01-01"))))
    (unwind-protect
        (progn
          (countdown-modeline-save-events)
          (let ((form (with-temp-buffer
                        (insert-file-contents tmp)
                        (goto-char (point-min))
                        (read (current-buffer)))))
            (should (= countdown-modeline--save-format-version
                       (plist-get form :format-version)))
            (should (equal '(("X" "2026-01-01"))
                           (plist-get form :events)))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-legacy-bare-list ()
  "Legacy files (a bare events list, no envelope) still load."
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events nil))
    (unwind-protect
        (progn
          (with-temp-file tmp
            (insert ";;; legacy file with no envelope\n"
                    "((\"Old\" \"2026-01-01\" \"L\") (\"Plain\" \"2027-02-02\"))\n"))
          (countdown-modeline-load-events)
          (should (equal countdown-modeline-events
                         '(("Old" "2026-01-01" "L")
                           ("Plain" "2027-02-02")))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-rejects-future-version ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("Keep" "2026-01-01"))))
    (unwind-protect
        (progn
          (with-temp-file tmp
            (let ((print-level nil) (print-length nil))
              (pp `(:format-version
                    ,(1+ countdown-modeline--save-format-version)
                    :events (("Future" "2026-01-01")))
                  (current-buffer))))
          (should-error (countdown-modeline-load-events) :type 'user-error)
          (should (equal countdown-modeline-events
                         '(("Keep" "2026-01-01")))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-rejects-envelope-missing-events ()
  "An envelope with a valid version but no :events key must error,
not silently wipe the user's in-memory events."
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("Keep" "2026-01-01"))))
    (unwind-protect
        (progn
          (with-temp-file tmp (insert "(:format-version 1)"))
          (should-error (countdown-modeline-load-events) :type 'user-error)
          (should (equal countdown-modeline-events
                         '(("Keep" "2026-01-01")))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-accepts-envelope-explicit-nil-events ()
  "An envelope with :events explicitly set to nil should load successfully
as an empty events list."
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("OldData" "2026-01-01"))))
    (unwind-protect
        (progn
          (with-temp-file tmp (insert "(:format-version 1 :events nil)"))
          (countdown-modeline-load-events)
          (should (null countdown-modeline-events)))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-rejects-missing-version ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("Keep" "2026-01-01"))))
    (unwind-protect
        (progn
          (with-temp-file tmp
            (insert "(:events ((\"X\" \"2026-01-01\")))"))
          (should-error (countdown-modeline-load-events) :type 'user-error)
          (should (equal countdown-modeline-events
                         '(("Keep" "2026-01-01")))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-load-rejects-garbage-form ()
  (let* ((tmp (make-temp-file "cm-test-" nil ".eld"))
         (countdown-modeline-events-file tmp)
         (countdown-modeline-events '(("Keep" "2026-01-01"))))
    (unwind-protect
        (progn
          (with-temp-file tmp (insert "42"))
          (should-error (countdown-modeline-load-events) :type 'user-error)
          (should (equal countdown-modeline-events
                         '(("Keep" "2026-01-01")))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest countdown-modeline-test-auto-save-failure-is-warning-not-error ()
  "If auto-save fails, the in-memory change still succeeds and the
caller sees a warning, not a propagated error."
  (let* ((countdown-modeline-events-file "/proc/no-such-dir/events.eld")
         (countdown-modeline-save-events-on-change t)
         (countdown-modeline-events nil)
         (warning-count 0))
    (cl-letf (((symbol-function 'display-warning)
               (lambda (&rest _) (cl-incf warning-count))))
      (countdown-modeline-add-event "X" "2026-01-01")
      (should (= 1 warning-count))
      (should (equal countdown-modeline-events '(("X" "2026-01-01")))))))

(ert-deftest countdown-modeline-test-save-creates-parent-directory ()
  (let* ((parent (make-temp-file "cm-test-dir-" t))
         (subdir (expand-file-name "nested/deeper" parent))
         (countdown-modeline-events-file
          (expand-file-name "events.eld" subdir))
         (countdown-modeline-events '(("X" "2026-01-01"))))
    (unwind-protect
        (progn
          (countdown-modeline-save-events)
          (should (file-exists-p countdown-modeline-events-file))
          (should (file-directory-p subdir)))
      (delete-directory parent t))))

(ert-deftest countdown-modeline-test-list-events-empty ()
  (let ((countdown-modeline-events nil))
    (save-window-excursion
      (countdown-modeline-list-events)
      (with-current-buffer "*countdown-modeline events*"
        (should (string-match-p "no events configured" (buffer-string)))))))

(ert-deftest countdown-modeline-test-midnight-tick-noop-when-disabled ()
  ;; Ensure the mode is off and no timer exists.
  (countdown-modeline-mode -1)
  (setq countdown-modeline--timer nil
        countdown-modeline--string nil)
  (countdown-modeline--midnight-tick)
  (should (null countdown-modeline--timer))
  (should (null countdown-modeline--string)))

(provide 'countdown-modeline-tests)
;;; countdown-modeline-tests.el ends here
