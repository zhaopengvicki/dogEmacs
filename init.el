;; Minimal setup for Clojure development & Org document.

(require 'package)
(setq package-enable-at-startup nil)

(setq package-archives
      '(("gnu-cn" . "http://elpa.zilongshanren.com/gnu/")
        ("melpa-cn" . "http://elpa.zilongshanren.com/melpa/")
        ("melpa-stable-cn" . "http://elpa.zilongshanren.com/melpa-stable/")
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


;; If README.el exists, load README.el directly.
;; Otherwise, use org-babel-load-file.
(if (file-exists-p "~/.emacs.d/README.el")
    (load-file "~/.emacs.d/README.el")
  (cl-letf (((symbol-function 'message) #'format))
    (org-babel-load-file (expand-file-name "~/.emacs.d/README.org"))))


(message "Initialize Finished!")
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (window-divider-mode diff-hl centered-window-mode zenburn-theme white-theme use-package undo-tree solarized-theme restclient realgud rainbow-delimiters parenface2 parenface-plus parenface org-plus-contrib org-bullets neotree minimal-theme meghanada magit kaolin-themes hugsql-ghosts hl-sexp highlight-symbol hideshowvis grayscale-theme goose-theme google-c-style git-gutter-fringe+ git-gutter flycheck-pos-tip flycheck-clojure expand-region exec-path-from-shell ert-expectations emmet-mode easy-kill dummyparens dummy-package dracula-theme diminish creamsody-theme counsel-projectile clj-refactor autodisass-java-bytecode anzu ag ace-window)))
 '(tramp-syntax (quote default) nil (tramp)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:foreground "gray20"))))
 '(font-lock-builtin-face ((t (:foreground "gray30" :bold t))))
 '(whitespace-line ((t (:background nil :foreground "red")))))
