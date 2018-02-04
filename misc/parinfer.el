;;; parinfer.el --- Simpler Lisp editing

;; Copyright (c) 2016, Shi Tianshu

;; Author: Shi Tianshu
;; Homepage: https://github.com/DogLooksGood/parinfer-mode
;; Version: 0.5.0
;; Package-Requires: ((dash "2.13.0") (cl-lib "0.5"))
;; Keywords: Parinfer

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Installation

;; * Clone this repo.
;; #+BEGIN_SRC shell
;;   cd /some/path/parinfer-mode
;;   git clone https://github.com/DogLooksGood/parinfer-mode.git
;; #+END_SRC
;; * Emacs configurations.
;; #+BEGIN_SRC emacs-lisp
;;   ;; Add parinfer-mode to load-path.
;;   (add-to-list 'load-path "~/some/path/parinfer-mode")
;;   ;; Require it!
;;   (require 'parinfer)
;; #+END_SRC

;;; Commentary:
;; For now, project will be updated frequently.
;; The document is hosted on github.
;; https://github.com/DogLooksGood/parinfer-mode

;;; Code:

(require 'paredit)
(require 'cl-lib)

(defvar parinfer--ignore-commands
  '(undo undo-tree-undo undo-tree-redo
         parinfer-shift-left parinfer-shift-right
         clojure-align yank yank-pop))

(defvar parinfer--max-process-lines 200)

(defvar-local parinfer--x nil)

(defvar-local parinfer--orig-pos nil)

(defvar-local parinfer--line nil)

(defvar-local parinfer--lock-begin nil
  "The beginning of the locked sexp, this sexp will neither slurp nor barf.")

(defvar-local parinfer--lock-end nil
  "The end of the locked sexp.")

(defvar-local parinfer--delta nil)

(defvar-local parinfer--in-comment nil)

(defvar-local parinfer--last-error nil)

(defvar-local parinfer--old-cursor-color nil)

(defvar-local parinfer--mark nil)

(defvar-local parinfer--parse-in-string nil)

(defvar-local parinfer--change-pos nil)

(defvar-local parinfer--buffer-will-change nil)

(defvar-local parinfer--parse-result nil)

(defvar-local parinfer--parse-line nil)

(defvar-local parinfer--parse-line-end nil)

(defvar-local parinfer--prev-x nil)

(defvar-local parinfer--simple-delete nil)

(defvar-local parinfer--process-range ())

(defvar-local parinfer--paren-stack ()
  "Element should be (paren point)")

(defvar parinfer--dev nil)

(defvar-local parinfer--op-stack ()
  "Element should be (point :insert/:delete insert-text/delete-N)")

(defun parinfer--log (s &rest args)
  (when parinfer--dev
    (apply #'message (concat "[Parinfer]:" s)
           args)))

(defun parinfer--get-line ()
  (let ((result (elt parinfer--parse-result (point))))
    (if result
        (car result)
      (progn
        ;; (parinfer--log "get unparse line: %s" (point))
        (parinfer--log "unparse-op")
        (1- (line-number-at-pos (point)))))))

(defun parinfer--get-x ()
  (- (point) (line-beginning-position)))

(defun parinfer--get-indent ()
  (if (or (parinfer--empty-line-p)
          (parinfer--line-begin-with-comment-p)
          (parinfer--line-begin-with-closer-p)
          (parinfer--line-begin-with-string-literals-p))
      0
    (save-excursion
      (back-to-indentation)
      (parinfer--get-x))))

(defun parinfer--opener-to-closer (opener)
  (cond
   ((= opener 40) 41)
   ((= opener 91) 93)
   ((= opener 123) 125)))

(defun parinfer--closer-to-opener (closer)
  (cond
   ((= closer 41) 40)
   ((= closer 93) 91)
   ((= closer 125) 123)))

(defun parinfer--repeat-string (s n)
  (let ((r "")
        (i 0))
    (while (< i n)
      (setq r (concat r s))
      (setq i (1+ i)))
    r))

(defun parinfer--get-process-range ()
  "Return (begin, end)."
  (save-mark-and-excursion
    (let* ((pos (point))
           (orig-line-begin (line-beginning-position))
           (begin (point-min))
           (end (point-max))
           (break nil))
      (while (and (> (point) (point-min))
                  (not break))
        (forward-line -1)
        (when (and (= (point) (save-excursion (back-to-indentation) (point)))
                 (not (parinfer--string-p))
                 (not (parinfer--comment-p))
                 (not (parinfer--empty-line-p)))
          (setq begin (point)
                break t)))
      (goto-char pos)
      (setq break nil)
      (while (and (< (point) (point-max))
                  (not break))
        (forward-line 1)
        (unless (= (point) (point-max))
          (when (parinfer--zero-indent-p)
            (setq break t))))
      (if (= orig-line-begin
             (line-beginning-position))
          (setq end (line-end-position))
        (progn
          (when (parinfer--zero-indent-p)
            (forward-line -1))
          (setq end (line-end-position))))
      (cons begin end))))

(defun parinfer--clear-parse-result ()
  (setq parinfer--parse-result nil))

(defun parinfer--parse-get-line (p)
  (when (> p parinfer--parse-line-end)
    (setq parinfer--parse-line (1+ parinfer--parse-line)
          parinfer--parse-line-end (save-excursion (goto-char p) (line-end-position))))
  parinfer--parse-line)

(defun parinfer--parse-1 (end)
  (let ((current (point)))
    (skip-syntax-forward "^<^\"" end)
    (cond
     ((parinfer--char-p)
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))
      (forward-char 1))
     ((parinfer--parse-comment-p)
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))
      (cl-loop for i from (point) to (line-end-position) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 1)))
      (forward-line 1))

     ;; TODO
     ;; Escape string with forward-sexp & backward-up-list is not fast.
     ;; Here we can introduce a variable for parser state.
     ((parinfer--parse-string-p)
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))
      (setq current (point))
      (when (= (point) (point-max))
        (error "Can't escape string!"))
      (forward-char 1)
      (parinfer--escape-string end t)
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 2))))
     (t
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))))))

(defun parinfer--parse-2 (end)
  (let ((current (point)))
    (if parinfer--parse-in-string
        (skip-syntax-forward "^\"")
      (skip-syntax-forward "^<^\"" end))
    (cond
     ((and (not parinfer--parse-in-string) (parinfer--char-p))
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))
      (forward-char 1))
     ((and (not parinfer--parse-in-string) (parinfer--parse-comment-p))
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))
      (cl-loop for i from (point) to (line-end-position) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 1)))
      (forward-line 1))

     ;; Escape string with forward-sexp & backward-up-list is not fast.
     ;; Here we can introduce a variable for parser state.
     ((parinfer--parse-string-p)
      (if (and parinfer--parse-in-string
               (char-after)
               (save-excursion (forward-char)
                               (not (parinfer--parse-string-p))))
          (progn
            (forward-char 1)
            (cl-loop for i from current to (point) do
                     (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 2)))
            (setq parinfer--parse-in-string nil))
        (progn
          (when (or (= (point) (point-max))
                    (>= (point) (+ end 8000)))
            (error "Can't escape string!"))
          (cl-loop for i from current to (point) do
                   (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))
          (forward-char 1)
          (setq parinfer--parse-in-string t))))
     (t
      (when parinfer--parse-in-string
        (error "Can't escape string!"))
      (cl-loop for i from current to (point) do
               (aset parinfer--parse-result i (cons (parinfer--parse-get-line i) 0)))))))

(defun parinfer--parse (&optional begin end)
  "Parse the buffer content from begin to end,
if they aren't provided, parse the whole buffer.
save (line-number[zero based] type) for each point in parinfer--parse-result.
type:
  1. code
  2. comment
  3. string

This function try to solve the problem that get line number and
detect if cursor in comment are slow."
  (setq parinfer--parse-in-string nil)
  (parinfer--log "parse begin")
  (let ((begin (or begin (point-min)))
        (end (or end (point-max)))
        (end-of-buffer nil))
    (save-excursion
      (setq parinfer--parse-result
            (make-vector (+ 2 (- (point-max) (point-min)))
                         nil))
      (goto-char begin)
      (setq parinfer--parse-line-end (line-end-position)
            parinfer--parse-line (1- (line-number-at-pos begin)))
      (while (and (>= end (point))
                  (not end-of-buffer))
        (parinfer--parse-2 (min (1+ end) (point-max)))
        (when (= (point) (point-max))
          (setq end-of-buffer t)))))
  (parinfer--log "parse end"))

;; -----------------------------------------------------------------------------
;;
;;   PREDICATES
;;
;; -----------------------------------------------------------------------------

(defun parinfer--simple-insert-p ()
  "when self-insert-command, only space, backslash, doublequote, paren, semicolon can affect parens."
  (when (equal this-command 'self-insert-command)
    (or (parinfer--empty-line-p)
        (and (not (<= (point) (save-excursion
                                (back-to-indentation)
                                (1+ (point)))))
             (char-before)
             (let ((ch (char-before)))
               (not (or (= ch 34)
                        (= ch 59)
                        (= ch 40)
                        (= ch 41)
                        (= ch 91)
                        (= ch 93)
                        (= ch 123)
                        (= ch 125)
                        (= ch 92))))))))

(defun parinfer--simple-delete-p (start end)
  (when (and (equal this-command 'parinfer--backward-delete)
             (= 1 (- end start)))
    (or (parinfer--empty-line-p)
        (and (not (<= start (save-excursion
                              (goto-char start)
                              (back-to-indentation)
                              (1+ (point)))))
             (let ((ch (char-after start)))
               (not (or (= ch 34)
                        (= ch 59)
                        (= ch 40)
                        (= ch 41)
                        (= ch 91)
                        (= ch 93)
                        (= ch 123)
                        (= ch 125)
                        (= ch 92))))))))

(defun parinfer--skip-p ()
  (or ;; (region-active-p)
   (bound-and-true-p multiple-cursors-mode)
   (bound-and-true-p cua-mode)
   (seq-contains parinfer--ignore-commands this-command)))

(defun parinfer--opener-p ()
  (and (not (parinfer--char-p))
       (let ((ch (char-after (point))))
         (and ch
              (or (= ch 40)
                  (= ch 91)
                  (= ch 123))))))

(defun parinfer--closer-p ()
  (and (not (parinfer--char-p))
       (let ((ch (char-after (point))))
         (and ch
              (or (= ch 41)
                  (= ch 93)
                  (= ch 125))))))

(defun parinfer--prev-char-whitespace-or-closer-p ()
  (and (char-before)
       (or
        (= 32 (char-before))
        (save-excursion
          (backward-char)
          (parinfer--closer-p)))))

(defun parinfer--unstable-closer-p ()
  (string-match-p
   "^[])}]+ *\\(?:;.*\\)?$"
   (buffer-substring-no-properties (point)
                                   (line-end-position))))

(defun parinfer--at-buffer-last-empty-line-p ()
  (and (= (point) (point-max))
       (= (line-beginning-position)
          (line-end-position))))

(defun parinfer--char-p ()
  (paredit-in-char-p))

(defun parinfer--parse-string-p ()
  ;; (parinfer--log "unparse string-p: %s" (point))
  (parinfer--log "unparse-op")
  (or
   (and (< (point) (point-max))
        (save-excursion
          (forward-char)
          (nth 3 (syntax-ppss))))
   (nth 3 (syntax-ppss))))

(defun parinfer--string-p ()
  (let ((result (elt parinfer--parse-result (point))))
    (if result
        (= 2 (cdr result))
      (parinfer--parse-string-p))))

(defun parinfer--zero-indent-p ()
  (and (= (point)
          (line-beginning-position))
       (parinfer--indent-p)))

(defun parinfer--indent-p ()
  (and (= (point) (save-excursion (back-to-indentation) (point)))
       (not (or (parinfer--empty-line-p)
                (parinfer--line-begin-with-string-literals-p)
                (parinfer--line-begin-with-comment-p)
                (parinfer--line-begin-with-closer-p)))))

(defun parinfer--parse-comment-p ()
  ;; (parinfer--log "unparse comment-p: %s" (point))
  (parinfer--log "unparse-op")
  (save-excursion
    (when (< (point) (point-max))
      (forward-char)
      (nth 4 (syntax-ppss)))))

(defun parinfer--comment-p ()
  (let ((result (elt parinfer--parse-result (point))))
    (if result
        (= 1 (cdr result))
      (parinfer--parse-comment-p))))

(defun parinfer--line-end-in-string-p ()
  (save-mark-and-excursion
    (goto-char (line-end-position))
    (parinfer--string-p)))

(defun parinfer--line-begin-with-comment-p ()
  (string-match-p
   "^ *;.*$"
   (buffer-substring-no-properties (line-beginning-position)
                                   (line-end-position))))

(defun parinfer--line-begin-with-closer-p ()
  (save-mark-and-excursion
    (back-to-indentation)
    (parinfer--unstable-closer-p)))

(defun parinfer--line-begin-with-string-literals-p ()
  (save-mark-and-excursion
    (goto-char (line-beginning-position))
    (parinfer--string-p)))

(defun parinfer--line-end-p ()
  "Return if we are at the end of line."
  (= (point) (line-end-position)))

(defun parinfer--trail-paren-p ()
  "Return if we are before a trail paren."
  (string-match-p
   "^[])}]+ *\\(?:;.*\\)?$"
   (buffer-substring-no-properties (point)
                                   (line-end-position))))

(defun parinfer--empty-line-p ()
  "Return if current line is a blank line."
  (or (eq (line-beginning-position) (line-end-position))
      (string-match-p
       "^[[:blank:]]+$"
       (buffer-substring-no-properties (line-beginning-position)
                                       (line-end-position)))))

(defun parinfer--end-of-code-p (&optional check-comment-p)
  "The end of code, ignore the following comment.
This will ensure the current X is greater than parinfer--x if
current line is parinfer--line."
  (let ((ch (char-before)))
    (or (= (point) (point-max))
        (and ch
             (not (= (line-beginning-position) (point)))
             (not (parinfer--string-p))
             (string-match-p "^[])} ]*\\(?:;.*\\)?$"
                             (buffer-substring-no-properties
                              (point) (line-end-position)))
             (not (parinfer--line-end-in-string-p))
             (not (parinfer--char-p))
             (and parinfer--line
                  (or (not (= (parinfer--get-line) parinfer--line))
                      (and (= (parinfer--get-line) parinfer--line)
                           (or (>= (parinfer--get-x) parinfer--x)

                               ;; For case:
                               ;; (do)
                               ;;    ^ insert ;
                               ;;------------
                               ;; (do);
                               ;;
                               (save-excursion
                                 (goto-char (line-beginning-position))
                                 (parinfer--goto-x parinfer--x)
                                 (parinfer--comment-p))
                               )
                           )))
             ;; Only first end-of-code is available,
             ;; so there's no need to check if we are in comment.
             (if (not check-comment-p)
                 t
               (save-mark-and-excursion
                 (backward-char)
                 (not (parinfer--comment-p))))
             ))))

;; -----------------------------------------------------------------------------
;;
;;   NAVIGATIONS
;;
;; -----------------------------------------------------------------------------

(defun parinfer--escape-comment ()
  (while (and (> (point) (point-min))
              (parinfer--comment-p))
    (if (parinfer--line-begin-with-comment-p)
        (forward-line -1)
      (backward-char)))
  (forward-char))

(defun parinfer--goto-next-indentation (&optional end)
  "Goto the next indentation and return t if cursor move to the indentation,
return nil if there's no more indentation position.
  This function must be called when cursor is on one indentation or point-min, otherwise always return nil."
  (when (= (point) (point-min))
    (while (and (or (parinfer--empty-line-p)
                    (parinfer--line-begin-with-comment-p))
                (> end (point)))
      (forward-line))
    (back-to-indentation))
  (if (and (parinfer--indent-p)
           (> end (point)))
      (let ((end (or end (point-max)))
            (begin (point)))
        (forward-line)
        (back-to-indentation)
        (cond
         ((= (point) begin)
          (goto-char (line-end-position))
          t)
         ((> (point) end)
          (goto-char begin)
          (goto-char (line-end-position))
          t)
         (t
          (setq begin (point))
          (let ((not-move nil))
            (while (and (not not-move)
                        (> end (point))
                        (or (parinfer--empty-line-p)
                            (parinfer--line-begin-with-string-literals-p)
                            (parinfer--line-begin-with-comment-p)
                            (parinfer--line-begin-with-closer-p)))
              (forward-line)
              (back-to-indentation)
              (if (= (point) begin)
                  (setq not-move t)
                (setq begin (point))))
            (if (or not-move (>= (point) end))
                (progn (goto-char end)
                       (goto-char (line-end-position))
                       t)
              t)))))
    nil))

(defun parinfer--goto-end-of-code ()
  (while (not (parinfer--end-of-code-p t))
    (forward-word)))

(defun parinfer--goto-next-opener-or-closer-or-end-of-code (&optional end)
  "Goto the next opener, closer or end-of-code.
Return :opener, :closer or :end-of-code. If current point greater than end, goto end and return :end-of-code."
  (let ((end (or end (point-max))))
    (if (<= end (point))
        (progn
          (goto-char end)
          :end-of-code)
      (let ((found nil)
            (prev-ending-pos nil)
            (end-of-buffer nil))
        (while (and (not found)
                    (> end (point)))
          (cond
           ((and (or (not prev-ending-pos)
                     (> (point) prev-ending-pos))
                 (parinfer--end-of-code-p))
            (progn (setq found :end-of-code)
                   (save-mark-and-excursion
                     (goto-char (line-end-position))
                     (setq prev-ending-pos (point)))))

           ((parinfer--string-p)
            (parinfer--go-over-string end))

           ((parinfer--comment-p)
            (forward-line))

           ((parinfer--closer-p)
            (setq found :closer))

           ((parinfer--opener-p)
            (setq found :opener))

           (t
            (progn
              (forward-char)
              ;; (if (and parinfer--line
              ;;          (= parinfer--line (parinfer--get-line)))
              ;;     (forward-char)
              ;;   (when (zerop (skip-syntax-forward "^(^)^w" end))
              ;;     (forward-symbol 1)))
              )))
          (when (= (point) (point-max))
            (setq end-of-buffer t)))
        ;; (message "%s is %s" (point) found)
        (when (> (point) end)
          (goto-char end))
        (or found :end-of-code)))))

(defun parinfer--goto-tail-sexp-opener ()
  (let ((paren-stack ())
        (pos nil)
        (end (line-end-position))
        (end-in-comment (save-mark-and-excursion
                          (goto-char (line-end-position))
                          (parinfer--comment-p))))
    (while (> end (point))
      (cond
       ((and end-in-comment (parinfer--comment-p))
        (goto-char end))

       ((parinfer--opener-p)
        (progn (unless paren-stack (setq pos (point)))
               (push (char-after) paren-stack)))

       ((parinfer--closer-p)
        (pop paren-stack)))
      (when (> end (point))
        (forward-char)))

    (if pos
        (progn (goto-char pos) t)
      nil)))

(defun parinfer--goto-line (line)
  (goto-char (point-min))
  (forward-line line))

(defun parinfer--goto-x (x)
  (if (> (- (line-end-position) (line-beginning-position))
         x)
      (forward-char x)
    (goto-char (line-end-position))))

(defun parinfer--go-over-string (&optional end)
  "Fast, need parse result."
  (let ((p (point)))
    (let ((end (or end (point-max))))
      (while (and (< (point) (point-max))
                  (parinfer--string-p))
        (forward-char))
      (when (< end (point))
        (error (format "Can't escape string! point:%s" p))))))

(defun parinfer--escape-string (&optional end throw-error)
  (let ((p (point)))
    (let ((end (or end (point-max))))
      (if (ignore-errors
            (backward-up-list 1 t)
            (forward-sexp)
            t)
          (if (>= end (point))
              t
            (if throw-error
                (error (format "Can't escape string! point:%s" p))
              nil))
        (if throw-error
            (error (format "Can't escape string! point:%s" p))
          nil)))))

;; (defun parinfer--goto-last-end-of-code (begin)
;;   (let ((found nil)
;;         (pos nil)
;;         (break nil))
;;     (while (not break)
;;       (cond
;;        ((and (not found)
;;              (parinfer--end-of-code-p))
;;         (setq pos (point)
;;               found t)
;;         (backward-char))

;;        ((and found
;;              (parinfer--end-of-code-p))
;;         (setq pos (point))
;;         (backward-char))

;;        ((and found
;;              (not (parinfer--end-of-code-p)))
;;         (setq break t)
;;         (backward-char))

;;        (t
;;         )))))

;; -----------------------------------------------------------------------------
;;
;;   PROCEDURES
;;
;; -----------------------------------------------------------------------------

(defun parinfer--fix-end-empty-line ()
  (if (= (point-min) (point-max))
      (newline)
    (progn
      (goto-char (point-max))
      (unless (= (line-beginning-position) (line-end-position))
        (goto-char (line-end-position))
        (newline)))))

(defun parinfer--save-position ()
  (setq parinfer--orig-pos (point))
  (setq parinfer--x (parinfer--get-x))
  (setq parinfer--line
        ;; Here we need always get the true line number
        ;; (parinfer--get-line) will give the wrong line number
        ;; when we do M-<
        (1- (line-number-at-pos (point)))))

(defun parinfer--restore-position ()
  (parinfer--goto-line parinfer--line)
  (if (< (- (line-end-position) (line-beginning-position))
         parinfer--x)
      (goto-char (line-end-position))
    ;; (messag "parinfer--restore-position begin")
    (forward-char parinfer--x)
    ;; (messag "parinfer--restore-position end")
    ))

(defun parinfer--correct-closer ()
  (let* ((opener (pop parinfer--paren-stack))
         (ch (car opener))
         (correct-ch (parinfer--opener-to-closer ch)))
    (unless (= correct-ch (char-after))
      (push (list (point) :insert correct-ch) parinfer--op-stack)
      (push (list (point) :delete 1) parinfer--op-stack))))

(defun parinfer--clear-paren-stack-and-insert ()
  (let ((break nil))
    (while (not break)
      (let ((opener (pop parinfer--paren-stack)))
        (if opener
            (let* ((ch (car opener))
                   (closer-ch (parinfer--opener-to-closer ch)))
              (push (list (point) :insert closer-ch)
                    parinfer--op-stack))
          (setq break t))))))

(defun parinfer--insert-unstable-parens (indent)
  ;; If end of code is followed by a closer.
  ;; This closer must be an unstable closer.
  ;; and it will not be searched again,
  ;; so we remove it here.
  ;; (message "insert unstable parens, point: %s, indent: %s" (point) indent)
  (if (< parinfer--lock-begin (point) parinfer--lock-end)
      (when (parinfer--closer-p)
        (parinfer--correct-closer))
    (progn
        (let ((break nil))
          (while (not break)
            (let ((last-opener (pop parinfer--paren-stack)))
              (if (not last-opener)
                  (setq break t)
                (let* ((ch (car last-opener))
                       (i (cadr last-opener))
                       (closer (parinfer--opener-to-closer ch)))
                  (if (>= i indent)
                      (push (list (point) :insert closer)
                            parinfer--op-stack)
                    (progn
                      (push last-opener parinfer--paren-stack)
                      (setq break t))))))))
        (when (parinfer--closer-p)
          (push (list (point) :delete 1) parinfer--op-stack)))))

(defun parinfer--reindent-last-changed-maybe ()
  "Goto the change-pos, reindent the sexp there,
and reindent all the  lines following."
  (let ((line (car parinfer--change-pos))
        (x (cdr parinfer--change-pos)))
    (when (not (and (= (1- (line-number-at-pos (point))) line)
                    (<= (parinfer--get-x) x)))
      (parinfer--goto-line line)
      (if (> (- (line-end-position) (line-beginning-position))
             x)
          (forward-char x)
        (goto-char (line-end-position)))
      (ignore-errors
        (unless (= (point) (line-beginning-position))
          (backward-up-list))
        (indent-sexp)
        (forward-sexp))

      ;; indent following lines
      (forward-line)
      (let ((break nil))
        (while (and (not break)
                    (not (= (point) (point-max))))
          (unless (parinfer--line-begin-with-comment-p)
            (let ((old-indent (parinfer--get-indent)))
              (lisp-indent-line)
              (when (= old-indent
                       (parinfer--get-indent))
                (setq break t))))
          (forward-line)))

      ;; handle whitespaces
      (parinfer--goto-line line)
      (unless (parinfer--line-begin-with-comment-p)
        (goto-char (line-end-position))
        (when (and (char-before)
                   (save-excursion
                     (backward-char)
                     (parinfer--comment-p)))
          (backward-char))
        (while (and (> (point) (line-beginning-position))
                    (parinfer--comment-p))
          (backward-char))
        (unless (= (point) (line-beginning-position))
          (while (parinfer--prev-char-whitespace-or-closer-p)
            (if (= 32 (char-before))
                (delete-char -1)
              (backward-char)))))
      (setq parinfer--change-pos nil)
      (setq parinfer--buffer-will-change nil))))

(defun parinfer--execute-op-1 (op)
  (let ((pos (car op))
        (op-type (cadr op))
        (arg (caddr op)))
    (if (eq op-type :insert)
        (progn
          ;; May need shift some point variables
          (goto-char pos)
          (insert arg))
      (progn
        ;; May need shift some point variables
        (goto-char pos)
        (delete-char arg)))))

(defun parinfer--op-sort-function (x y)
  "We only need to sort by point"
  (> (car x) (car y)))

;; (let ((xs (list '(3 :a) '(3 :b) '(1 :b) '(1 :c) '(2 :a) '(2 :b))))
;;   (sort xs #'parinfer--op-sort-function))

(defun parinfer--execute-op ()
  ;; (message "%s" parinfer--op-stack)
  (mapc #'parinfer--execute-op-1
        (sort parinfer--op-stack
              #'parinfer--op-sort-function))
  (setq parinfer--op-stack ()))

(defun parinfer--fix-opener ()
  (let ((opener (char-after (point)))
        (x (parinfer--get-x)))
    (push (list opener x) parinfer--paren-stack)))

(defun parinfer--fix-closer ()
  "If in the lock range, just pop or update paren type."
  (if (< parinfer--lock-begin (point) parinfer--lock-end)
      (parinfer--correct-closer)
    (let ((in-edit-scope (and (= (parinfer--get-line) parinfer--line)
                              ;; If we want open [] in {},
                              ;; the current cursor position must not be in edit-scope
                              (<= (parinfer--get-x) parinfer--x))))
      (if (and (parinfer--unstable-closer-p)
               (not in-edit-scope))
          (push (list (point) :delete 1) parinfer--op-stack)
        (let* ((closer (char-after (point)))
               (last-opener-info (pop parinfer--paren-stack))
               (last-opener (car last-opener-info)))
          (cond
           ((not last-opener)
            (push (list (point) :delete 1) parinfer--op-stack))
           ((not (= last-opener (parinfer--closer-to-opener closer)))
            (if (equal this-command 'self-insert-command)
                (let ((correct-closer (parinfer--opener-to-closer last-opener)))
                  (push (list (point) :insert correct-closer) parinfer--op-stack)
                  (parinfer--fix-closer))
              (progn
                (push (list (point) :delete 1) parinfer--op-stack)
                (push last-opener-info parinfer--paren-stack))))))))))

(defun parinfer--fix-paren (begin end indent)
  "Fix paren from begin to end(not include)."
  (while (> end (point))
    (let ((type (parinfer--goto-next-opener-or-closer-or-end-of-code end)))
      (when (> end (point))
        (cond
         ((equal type :opener) (parinfer--fix-opener))
         ((equal type :closer) (parinfer--fix-closer))
         ((equal type :end-of-code) (parinfer--insert-unstable-parens indent)))
        (forward-char)))))

(defun parinfer--align-tail-sexp ()
  (parinfer--log "align tail sexp")
  (setq parinfer--lock-begin -1
        parinfer--lock-end -1)
  (let ((x (parinfer--get-x)))
    (when (and parinfer--prev-x
               (parinfer--goto-tail-sexp-opener)
               (not parinfer--in-comment)
               (not (parinfer--empty-line-p))
               (not (parinfer--comment-p)))
      (let* ((begin (point))
             (delta (- x parinfer--prev-x))
             (orig-x (- x delta)))
        (goto-char begin)
        (when (ignore-errors (forward-sexp) t)
          (let ((end (point)))
            (goto-char (line-beginning-position))
            (while (< begin (point))
              (if (> delta 0)
                  (push (list (point) :insert (parinfer--repeat-string " " delta))
                        parinfer--op-stack)
                  ;; (insert (parinfer--repeat-string " " delta))
                (push (list (point) :delete (abs delta))
                      parinfer--op-stack)
                ;; (delete-char (abs delta))
                )
              (forward-line -1))
            (setq parinfer--lock-begin begin
                  parinfer--lock-end end))))))
  (setq parinfer--prev-x nil)
  (parinfer--log "align tail sexp end"))

(defun parinfer--process ()
  ;; (message "process")
  (condition-case ex
      (unless (or (parinfer--skip-p)
                  (= (point-min) (point-max)))
        (if parinfer--buffer-will-change
            (parinfer--process-changing)
          (parinfer--process-moving))
        (when parinfer--last-error
          (setq parinfer--last-error nil)
          (when parinfer--old-cursor-color
            (set-cursor-color parinfer--old-cursor-color))))
    (error
     ;; (message "%s" ex)
     (let ((error-message (cadr ex)))
       (unless error-message
         (error (concat "Error unknown:" (symbol-name (car ex)))))
       (when (or (not parinfer--last-error)
                 (not (string-equal parinfer--last-error
                                    error-message)))
         (message error-message)
         (set-cursor-color "red")
         (setq parinfer--last-error error-message)))
     (parinfer--restore-position)))
  (setq parinfer--process-range nil
        parinfer--buffer-will-change nil
        parinfer--delta nil
        parinfer--in-comment nil))

(defun parinfer--process-moving ()
  (parinfer--log "process moving")
  (when parinfer--change-pos
    (parinfer--save-position)
    (parinfer--reindent-last-changed-maybe)
    (parinfer--restore-position))
  (parinfer--log "process moving end"))

(defun parinfer--process-changing-1 ()
  (let* ((begin (car parinfer--process-range))
         (end (cdr parinfer--process-range))
         (no-indent t)
         (last-indent-pos begin)
         (curr-indent-pos begin))
    (goto-char begin)
    (cl-loop until (not (parinfer--goto-next-indentation end)) do
             (setq no-indent nil)
             (setq last-indent-pos curr-indent-pos)
             (setq curr-indent-pos (point))
             (let ((indent (if (parinfer--indent-p)
                               (parinfer--get-x)
                             0)))
               (goto-char last-indent-pos)
               (parinfer--fix-paren last-indent-pos curr-indent-pos indent))
             )

    ;; Special case:
    ;; If no indent at all
    ;; like
    ;; )
    (when no-indent
      (parinfer--fix-paren begin end 0))

    ;; Special case:
    ;; We open at the end.
    ;; (when parinfer--paren-stack
    ;;   (parinfer--clear-paren-stack-and-insert))
    (when (and (= (point) end)
               parinfer--paren-stack)
      (parinfer--clear-paren-stack-and-insert))
    ))

(defun parinfer--process-changing ()
  ;; Save end-line and end-x
  ;; (message "process changing")
  ;; (message "px: %s x: %s" parinfer--prev-x (parinfer--get-x))
  (parinfer--log "process changing")
  (parinfer--save-position)
  (setq parinfer--op-stack ()
        parinfer--paren-stack ())
  (unless parinfer--delta
    (setq parinfer--delta 0))
  (setq parinfer--process-range
        (parinfer--get-process-range))
  (when parinfer--mark
    (save-excursion
      (goto-char parinfer--mark)
      (let ((range2 (parinfer--get-process-range)))
        (setq parinfer--process-range
              (cons (min (car parinfer--process-range)
                         (car range2))
                    (max (cdr parinfer--process-range)
                         (cdr range2)))
              parinfer--mark nil))))
  (parinfer--parse (car parinfer--process-range)
                   (cdr parinfer--process-range))
  (save-excursion
    (parinfer--align-tail-sexp))
  (parinfer--restore-position)
  (unless (or (parinfer--simple-insert-p)
              parinfer--simple-delete)
    (parinfer--process-changing-1))
  (parinfer--execute-op)
  (parinfer--restore-position)
  (parinfer--clear-parse-result)
  (setq parinfer--change-pos (cons (parinfer--get-line)
                                   (parinfer--get-x)))
  (parinfer--log "process changing end"))

(defun parinfer--before-change (start end)
  (unless parinfer--buffer-will-change
    (parinfer--log "before change")
    (if (parinfer--simple-delete-p start end)
        (setq parinfer--simple-delete t)
      (setq parinfer--simple-delete nil))
    (setq parinfer--buffer-will-change t
          ;; If we begin within comment, no need to care about lock sexp.
          ;; Here since we haven't parse the buffer, so use parinfer--parse-comment-p
          parinfer--in-comment (parinfer--parse-comment-p)
          ;; Used to calculate delta-x for align.
          parinfer--prev-x (parinfer--get-x))

    ;; Shim
    ;; If command is newline and indent,
    ;; the cursor will first do a backward char
    ;; so we have to incrment parinfer--prev-x
    ;; (when (equal this-command 'newline-and-indent)
    ;;   (setq parinfer--prev-x (1+ parinfer--prev-x)))

    (parinfer--log "before change end")))

(defun parinfer--after-change (start end len)
  (unless parinfer--delta
    (parinfer--log "after change")
    (setq parinfer--delta (if (zerop len)
                              (- end start)
                            (* -1 len)))
    ;; (message "start %s end %s len %s" start end len)
    (parinfer--log "after change end")))

;; -----------------------------------------------------------------------------
;;
;; COMMANDS
;;
;; -----------------------------------------------------------------------------

(defun parinfer--shift-text (distance)
  (if (use-region-p)
      (let ((mark (mark)))
        (setq parinfer--mark mark)
        (save-excursion
          (indent-rigidly (region-beginning)
                          (region-end)
                          distance)
          (parinfer-run)
          (push-mark mark t t)
          (setq deactivate-mark nil)))
    (indent-rigidly (line-beginning-position)
                    (line-end-position)
                    distance)))

(defun parinfer-shift-right (count)
  (interactive "p")
  (if (region-active-p)
      (parinfer--shift-text 2)
    (call-interactively #'indent-for-tab-command)))

(defun parinfer-shift-left (count)
  (interactive "p")
  (parinfer--shift-text -2))

(defun parinfer-comment (arg)
  (interactive "*P")
  (comment-dwim arg)
  (parinfer-run))

(defun parinfer--newline ()
  "Behaviour like `newline-and-indent'.
 This command work correctly with `before-change-functions' hook."
  (interactive)
  (while (and (char-before)
              (= 32 (char-before)))
    (delete-char -1))
  (newline)
  (lisp-indent-line))

(defun parinfer--backward-delete ()
  (interactive)
  (if (region-active-p)
      (progn (call-interactively #'delete-region)
             (parinfer-run))
    (call-interactively #'backward-delete-char)))

(defun parinfer-run ()
  (interactive)
  (setq parinfer--buffer-will-change t
        parinfer--in-comment (parinfer--parse-comment-p)
        parinfer--prev-x (parinfer--get-x)
        parinfer--delta 0)
  (parinfer--process-changing))

(defun parinfer-toggle-debug ()
  (interactive)
  (setq parinfer--dev (not parinfer--dev))
  (message "Parinfer debug mode: %s" (if parinfer--dev "on" "off")))

(defun parinfer-mode-enable ()
  (interactive)
  (setq-local parinfer--old-cursor-color
              (frame-parameter (selected-frame) 'cursor-color))
  (font-lock-add-keywords
   nil '((parinfer-pretty-parens:fontify-search . 'parinfer-pretty-parens:dim-paren-face)))
  (parinfer-pretty-parens:refresh)
  (when (bound-and-true-p electric-indent-mode)
    (electric-indent-local-mode -1))
  (when (bound-and-true-p paredit-mode)
    (paredit-mode -1))
  (setq parinfer--buffer-will-change nil
        parinfer--process-range nil
        parinfer--lock-begin nil
        parinfer--lock-end nil
        parinfer--prev-x nil)
  (add-hook 'post-command-hook #'parinfer--process t t)
  (add-hook 'before-change-functions #'parinfer--before-change t t)
  (add-hook 'after-change-functions #'parinfer--after-change t t))

(defun parinfer-mode-disable ()
  (interactive)
  (font-lock-remove-keywords
   nil '((parinfer-pretty-parens:fontify-search . 'parinfer-pretty-parens:dim-paren-face)))
  (parinfer-pretty-parens:refresh)
  (remove-hook 'before-change-functions #'parinfer--before-change t)
  (remove-hook 'post-command-hook #'parinfer--process t)
  (remove-hook 'after-change-functions #'parinfer--after-change t))

;; -----------------------------------------------------------------------------
;;
;; FACES
;;
;; -----------------------------------------------------------------------------

(defun parinfer-pretty-parens:fontify-search (limit)
  (let ((result nil)
        (finish nil)
        (bound (+ (point) limit)))
    (while (not finish)
      (if (re-search-forward "\\s)" bound t)
          (when (and (= 0 (string-match-p "\\s)*$" (buffer-substring-no-properties (point) (line-end-position))))
                     (not (eq (char-before (1- (point))) 92)))
            (setq result (match-data)
                  finish t))
        (setq finish t)))
    result))

(defun parinfer-pretty-parens:refresh ()
  (if (fboundp 'font-lock-flush)
      (font-lock-flush)
    (when font-lock-mode
      (with-no-warnings
        (font-lock-fontify-buffer)))))

(defface parinfer-pretty-parens:dim-paren-face
   '((((class color) (background dark))
      (:foreground "grey40"))
     (((class color) (background light))
      (:foreground "grey60")))
   "Parinfer dim paren face."
   :group 'parinfer-ext)

;; -----------------------------------------------------------------------------
;;
;; MODE
;;
;; -----------------------------------------------------------------------------

(defvar parinfer-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap newline] 'parinfer--newline)
    (define-key map [remap comment-dwim] 'parinfer-comment)
    (define-key map (kbd "TAB") 'parinfer-shift-right)
    (define-key map (kbd "<backtab>") 'parinfer-shift-left)
    (define-key map (kbd "}") 'self-insert-command)
    (define-key map (kbd "{") 'self-insert-command)
    (define-key map (kbd "<backspace>") 'parinfer--backward-delete)
    map))

;;;###autoload
(define-minor-mode parinfer-mode
  "Parinfer mode."
  nil "Parinfer" parinfer-mode-map
  (if parinfer-mode
      (parinfer-mode-enable)
    (parinfer-mode-disable)))

(provide 'parinfer)
;;; parinfer.el ends here
