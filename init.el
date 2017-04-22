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

(org-babel-load-file (expand-file-name "~/.emacs.d/README.org"))

;; (server-start)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (org-plus-contrib use-package spacemacs-theme smart-mode-line rainbow-delimiters parinfer org-bullets magit hl-sexp highlight-symbol git-gutter-fringe expand-region counsel-projectile company clj-refactor))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
