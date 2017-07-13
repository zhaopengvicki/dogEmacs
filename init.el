;; Minimal setup for Clojure development & Org document.

(require 'package)
(setq package-enable-at-startup nil)

(setq package-archives
      '(("gnu-cn" . "http://elpa.zilongshanren.com/gnu/")
        ("melpa-cn" . "http://elpa.zilongshanren.com/melpa/")
        ("melpa-stable-cn" . "	http://elpa.zilongshanren.com/melpa-stable/")
        ("marmalade-cn" . "http://elpa.zilongshanren.com/marmalade/")
        ("org-cn" . "http://elpa.zilongshanren.com/org/")))
(package-initialize)

;; -----------------------------------------------------------------------------
;; Use Package
;; -----------------------------------------------------------------------------

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(setq use-package-always-ensure t
      use-package-always-defer t)
(require 'org)
(require 'ob-tangle)
(require 'use-package)

;; -----------------------------------------------------------------------------
;; Basics
;; -----------------------------------------------------------------------------

(use-package cl)
(require 'cl)

(cl-letf (((symbol-function 'message) #'format))
  (org-babel-load-file (expand-file-name "~/.emacs.d/README.org")))

