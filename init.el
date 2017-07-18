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

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (spaceline-all-the-icons spaceline monroe zenburn-theme use-package ujelly-theme spacemacs-theme solarized-theme smart-mode-line sayid rainbow-delimiters parinfer org-plus-contrib org-bullets neotree magit leuven-theme hl-sexp highlight-symbol github-theme github-modern-theme git-gutter-fringe git-draft flycheck-tip flycheck-pos-tip flycheck-clojure expand-region exec-path-from-shell dracula-theme doom-themes darktooth-theme darcula-theme counsel-projectile company clj-refactor cider-eval-sexp-fu))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
