;;; -*- lexical-binding: t; -*-

(require 'parinfer-smart)
(require 'cl-lib)
(require 'dash)

(defun parinfer--str (&rest args)
  (apply #'concat
         (-interpose "\n" args)))

(defconst parinfer--test-modify-buffer-commands
  [newline-and-indent insert delete-char backward-delete-char
                      backward-kill-word kill-word
                      kill-line parinfer-shift-left parinfer-shift-right])

(defun parinfer--test-execute-command (c)
  (when (seq-contains parinfer--test-modify-buffer-commands (car c))
    (parinfer--before-change-hook nil nil))
  (eval c)
  (parinfer--post-command-hook))

(defun parinfer--test (id orig pos commands result)
  (with-temp-buffer
    (erase-buffer)
    (clojure-mode)
    (insert orig)
    (goto-char (point-min))
    (forward-line (car pos))
    (forward-char (cdr pos))
    (mapc #'parinfer--test-execute-command
          commands)
    (let ((text (buffer-substring-no-properties (point-min) (point-max))))
      (if (string-equal text result)
          (message "%s success!" id)
        (message "%s faild!\nresult=\n%s" id text)))))

;; -----------------------------------------------------------------------------
;; CASES
;; -----------------------------------------------------------------------------

(parinfer--test
 "case01"
 "(foo)"
 (cons 0 4)
 [(newline-and-indent)]
 "(foo\n )")

;; -----------------------------------------------------------------------------

(parinfer--test
 "case02"
 (parinfer--str "(let [a 1])")
 (cons 0 9)
 [(newline-and-indent)
  (right-char)]
 (parinfer--str "(let [a 1])"
                ""))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case03"
 (parinfer--str "()")
 (cons 0 1)
 [(newline-and-indent)]
 (parinfer--str "("
                " )"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case04"
 (parinfer--str "(let [{:keys [x]} data])")
 (cons 0 15)
 [(newline-and-indent)
  (right-char)]
 (parinfer--str "(let [{:keys [x]}"
                "      data])"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case05"
 (parinfer--str "(let [{:keys [x]} data]"
                "  (+ x 2))")
 (cons 0 15)
 [(newline-and-indent)
  (insert "y")
  (right-char)]
 (parinfer--str "(let [{:keys [x"
                "              y]} data]"
                "  (+ x 2))"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case06"
 (parinfer--str "(foo {:a 1"
                "      :b 2} hello)")
 (cons 1 10)
 [(newline-and-indent)
  (forward-line)]
 (parinfer--str "(foo {:a 1"
                "      :b 2}"
                "     hello)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case07"
 (parinfer--str "(foo {:a 1"
                "      :b 2} hello)")
 (cons 1 10)
 [(newline-and-indent)
  (insert "x")]
 (parinfer--str "(foo {:a 1"
                "      :b 2"
                "      x} hello)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case08"
 (parinfer--str "(foo"
                " {:a 1"
                "  :b 2})")
 (cons 1 1)
 [(backward-delete-char 1)]
 (parinfer--str "(foo)"
                "{:a 1"
                " :b 2}"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case09"
 (parinfer--str "(foo)")
 (cons 0 4)
 [(newline-and-indent)
  (backward-delete-char 1)]
 (parinfer--str "(foo)"
                ""))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case10"
 (parinfer--str "(foo)"
                "")
 (cons 1 0)
 [(insert " ")]
 (parinfer--str "(foo)"
                " "))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case11"
 (parinfer--str "(foo)"
                "")
 (cons 1 0)
 [(insert " a")]
 (parinfer--str "(foo"
                " a)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case12"
 (parinfer--str "(foo"
                " a)")
 (cons 1 3)
 [(backward-delete-char 1)
  (backward-delete-char 1)]
 (parinfer--str "(foo"
                " )"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case13"
 (parinfer--str "(foo"
                " a)")
 (cons 1 1)
 [(insert ";")]
 (parinfer--str "(foo)"
                " ;a)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case14"
 (parinfer--str "(foo)"
                " ;a)")
 (cons 1 2)
 [(backward-delete-char 1)]
 (parinfer--str "(foo"
                " a)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case15"
 (parinfer--str "(foo"
                " a)")
 (cons 0 0)
 [(insert ";")]
 (parinfer--str ";(foo"
                " a"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case16"
 (parinfer--str ";(foo"
                " a")
 (cons 0 1)
 [(backward-delete-char 1)]
 (parinfer--str "(foo"
                " a)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case17"
 (parinfer--str "(foo"
                " a)")
 (cons 1 0)
 [(kill-line)]
 (parinfer--str "(foo)"
                ""))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case18"
 (parinfer--str "(foo"
                " a)")
 (cons 0 0)
 [(kill-line)]
 (parinfer--str ""
                " a"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case19"
 (parinfer--str "foo")
 (cons 0 0)
 [(insert "(")]
 (parinfer--str "(foo)"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case20"
 (parinfer--str "(foo)")
 (cons 0 1)
 [(insert "[")]
 (parinfer--str "([foo])"))

;; -----------------------------------------------------------------------------

(parinfer--test
 "case21"
 (parinfer--str "(foo)")
 (cons 0 0)
 [(insert "[")]
 (parinfer--str "[(foo)]"))
