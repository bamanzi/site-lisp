;;; rect+.el --- Extensions to rect.el

;; Author: Masahiro Hayashi <mhayashi1120@gmail.com>
;; Keywords: extensions, data, tools
;; URL: http://github.com/mhayashi1120/Emacs-rectplus/raw/master/rect+.el
;; Emacs: GNU Emacs 22 or later
;; Version: 1.0.5

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; rect+.el provides extensions to rect.el

;;; Install:

;; Put this file into load-path'ed directory, and byte compile it if
;; desired. And put the following expression into your ~/.emacs.
;;
;;     (require 'rect+)
;;     (define-key ctl-x-r-map "C" 'rectplus-copy-rectangle)
;;     (define-key ctl-x-r-map "N" 'rectplus-insert-number-rectangle)
;;     (define-key ctl-x-r-map "\M-c" 'rectplus-create-rectangle-by-regexp)
;;     (define-key ctl-x-r-map "A" 'rectplus-append-rectangle-to-eol)
;;     (define-key ctl-x-r-map "R" 'rectplus-kill-ring-to-rectangle)
;;     (define-key ctl-x-r-map "K" 'rectplus-rectangle-to-kill-ring)
;;     (define-key ctl-x-r-map "\M-l" 'rectplus-downcase-rectangle)
;;     (define-key ctl-x-r-map "\M-u" 'rectplus-upcase-rectangle)

;; ********** Emacs 22 or earlier **********
;;     (require 'rect+)
;;     (global-set-key "\C-xrC" 'rectplus-copy-rectangle)
;;     (global-set-key "\C-xrN" 'rectplus-insert-number-rectangle)
;;     (global-set-key "\C-xr\M-c" 'rectplus-create-rectangle-by-regexp)
;;     (global-set-key "\C-xrA" 'rectplus-append-rectangle-to-eol)
;;     (global-set-key "\C-xrR" 'rectplus-kill-ring-to-rectangle)
;;     (global-set-key "\C-xrK" 'rectplus-rectangle-to-kill-ring)
;;     (global-set-key "\C-xr\M-l" 'rectplus-downcase-rectangle)
;;     (global-set-key "\C-xr\M-u" 'rectplus-upcase-rectangle)

;;; Code:

(require 'rect)

(defvar current-prefix-arg)

;;;###autoload
(defun rectplus-rectangle-to-kill-ring ()
  "Killed rectangle to normal `kill-ring'.
After executing this command, you can type \\[yank]."
  (interactive)
  (with-temp-buffer
    (yank-rectangle)
    ;;avoid message
    (let (message-log-max)
      (message ""))
    (kill-new (buffer-string)))
  (message (substitute-command-keys
	    (concat "Killed rectangle converted to normal text. "
		    "You can type \\[yank] now."))))

;;;###autoload
(defun rectplus-kill-ring-to-rectangle (&optional succeeding)
  "Make rectangle from clipboard or `kill-ring'.
After executing this command, you can type \\[yank-rectangle]."
  (interactive
   (let (str)
     (when current-prefix-arg
       (setq str (read-from-minibuffer "Succeeding string to killed: ")))
     (list str)))
  (let ((tab tab-width))
    (with-temp-buffer
      ;; restore
      (setq tab-width tab)
      (insert (current-kill 0))
      (goto-char (point-min))
      (let ((max 0)
	    str len list)
	(while (not (eobp))
	  (setq str (buffer-substring (line-beginning-position) (line-end-position)))
	  (when succeeding
	    (setq str (concat str succeeding)))
	  (setq len (string-width str))
	  (when (> len max)
	    (setq max len))
	  (setq list (cons str list))
	  (forward-line 1))
	(setq killed-rectangle
	      (rectplus-non-rectangle-to-rectangle (nreverse list) max)))))
  (message (substitute-command-keys
	    (concat "Killed text converted to rectangle. "
		    "You can type \\[yank-rectangle] now."))))

;;;###autoload
(defun rectplus-append-rectangle-to-eol (&optional preceeding)
  "Append killed rectangle to end-of-line sequentially."
  (interactive
   (let (str)
     (when current-prefix-arg
       (setq str (read-from-minibuffer "Preceeding string to append: ")))
     (list str)))
  (unless preceeding
    (setq preceeding ""))
  (save-excursion
    (mapc
     (lambda (x)
       (goto-char (line-end-position))
       (insert preceeding)
       (insert x)
       (forward-line 1))
     killed-rectangle)))

;;;###autoload
(defun rectplus-copy-rectangle (start end)
  "Copy rectangle area."
  (interactive "r")
  (deactivate-mark)
  (setq killed-rectangle (extract-rectangle start end)))

;;;###autoload
(defun rectplus-insert-number-rectangle (start end number-fmt &optional step start-from)
  "Insert incremental number into each left edges of rectangle's line.

START END is rectangle region to insert numbers.
 Which is allowed START over END. In this case, inserted descendant numbers.
 e.g
   1. In dired buffer type `\\<dired-mode-map>\\[dired-sort-toggle-or-edit]' \
to sort by modified date descendantly.
   2. Activate region from old file to new file.
   3. Do this command to make sequential file name ordered by modified date.

NUMBER-FMT may indicate start number and inserted format.
  \"1\"   => [\"1\" \"2\" \"3\" ...]
  \"001\" => [\"001\" \"002\" \"003\" ...]
  \" 1\"  => [\" 1\" \" 2\" \" 3\" ...]
  \" 5\"  => [\" 5\" \" 6\" \" 7\" ...]

This format indication more familiar than `rectangle-number-lines'
implementation, I think :-)

On the other hand NUMBER-FMT accept \"%d\" like format too.

  \"%03d\" => [\"001\" \"002\" \"003\" ...]
  \"%3d\" => [\"  1\" \"  2\" \"  3\" ...]
  \"file-%03d\" => [\"file-001\" \"file-002\" \"file-003\" ...]

START-FROM indicate number to start, more prior than NUMBER-FMT.
STEP is incremental count. Default is 1.
"
  (interactive
   (progn
     (unless mark-active
       (signal 'mark-inactive nil))
     (let ((beg (region-beginning))
	   (fin (region-end))
	   fmt step start-num)
       ;; swap start end if mark move backward to beginning-of-buffer
       (when (eq beg (point))
         (let ((tmp beg))
           (setq beg fin
                 fin tmp)))
       (setq fmt (rectplus-read-from-minibuffer
                     "Start number or format: "
                     ;; padding-char (space or zero) + number
                     ;; % style format string.
                     "\\(^[ ]*[0-9]*$\\|%\\)"))
       (when current-prefix-arg
	 (setq step (rectplus-read-number "Step: " 1))
         (unless (string-match "^[ 0-9]+$" fmt)
           (setq start-num (rectplus-read-number "Start from: " 1))))
       (deactivate-mark)
       (list beg fin fmt step start-num))))
  (let* ((min (min start end))
         (max (max start end))
         (lines (rectplus--count-lines min max))
         (fmt
          (cond
           ((string-match "^\\([0 ]\\)*[0-9]*$" number-fmt)
            (let* ((padchar (match-string 1 number-fmt))
                   (fmtlen (number-to-string (length number-fmt))))
              (concat "%" padchar fmtlen "d")))
           (t number-fmt)))
         (num (cond
               (start-from start-from)
               ((string-match "^[ 0-9]+$" number-fmt)
                (string-to-number number-fmt))
               (t 1)))
         (l 0)
         rect-lst)
    (unless (condition-case nil (format fmt 1) (error nil))
      (error "Invalid number format %s" fmt))
    (setq step (or step 1))
    (save-excursion
      (delete-rectangle min max)
      ;; computing list of insertings
      (while (< l lines)
        (setq rect-lst (cons (format fmt num) rect-lst))
        (setq num (+ step num)
              l (1+ l)))
      (when (>= end start)
        (setq rect-lst (nreverse rect-lst)))
      (goto-char min)
      (insert-rectangle rect-lst))))

;;;###autoload
(defun rectplus-create-rectangle-by-regexp (start end regexp)
  "Capture string matching to REGEXP.
Only effect to region if region is activated.
"
  (interactive
   (let* ((beg (if mark-active (region-beginning) (point-min)))
	  (end (if mark-active (region-end) (point-max)))
	  (regexp (rectplus-read-regexp "Regexp")))
     (list beg end regexp)))
  (let ((max 0)
	str len list)
    (save-excursion
      (save-restriction
	(narrow-to-region start end)
	(goto-char (point-min))
	(while (re-search-forward regexp nil t)
	  (setq str (match-string 0))
	  (setq len (string-width str))
	  (setq list (cons str list))
	  (when (> len max)
	    (setq max len)))))
    ;; fill by space
    (setq killed-rectangle
	  (rectplus-non-rectangle-to-rectangle (nreverse list) max))))

;;;###autoload
(defun rectplus-upcase-rectangle (start end)
  "Upcase rectangle"
  (interactive "*r")
  (rectplus-do-translate start end 'upcase))

;;;###autoload
(defun rectplus-downcase-rectangle (start end)
  "Downcase rectangle"
  (interactive "*r")
  (rectplus-do-translate start end 'downcase))

(defun rectplus--count-lines (start end)
  (let ((lines 0))
    (save-excursion
      (goto-char start)
      (while (and (<= (point) end)
                  (not (eobp)))
        (forward-line 1)
        (setq lines (1+ lines))))
    lines))

(defun rectplus-do-translate (start end translator)
  "TRANSLATOR is function accept one string argument and return string."
  (apply-on-rectangle
   (lambda (s e)
     (let* ((start (progn (move-to-column s) (point)))
	    (end (progn (move-to-column e) (point)))
	    (current (buffer-substring start end))
	    (new (funcall translator current)))
       (unless (string= current new)
	 (delete-region start end)
	 (insert new))))
   start end))

(defun rectplus-read-from-minibuffer (prompt must-match-regexp &optional default)
  "Check input string by MUST-MACH-REGEXP.
See `read-from-minibuffer'."
  (let (str)
    (while (null str)
      (setq str (read-from-minibuffer prompt default))
      (unless (string-match must-match-regexp str)
	(message "Invalid string!")
	(sit-for 0.5)
	(setq str nil)))
    str))

(defun rectplus-read-number (prompt default)
  (string-to-number (rectplus-read-from-minibuffer
		     prompt "^[-+]?[0-9]+$"
		     (number-to-string default))))

(defun rectplus-non-rectangle-to-rectangle (strings &optional max)
  (let ((fmt (concat "%-" (number-to-string max) "s")))
    (mapcar
     (lambda (s)
       (format fmt s))
     strings)))

(defun rectplus-read-regexp (prompt)
  (if (fboundp 'read-regexp)
      (read-regexp prompt)
    (read-from-minibuffer (concat prompt ": "))))

(provide 'rect+)

;;; rect+.el ends here
