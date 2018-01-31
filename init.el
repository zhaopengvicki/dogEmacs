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
    (company-childframe-mode use-package undo-tree tide smartparens rjsx-mode restclient realgud org-plus-contrib org-bullets nlinum neotree minimal-theme meghanada magit highlight-symbol highlight-parentheses hideshowvis google-c-style expand-region exec-path-from-shell easy-kill diminish diff-hl counsel-projectile company-childframe clj-refactor autodisass-java-bytecode anzu ag ace-window))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:foreground "gray20" :background "gray97"))))
 '(aw-leading-char-face ((t (:height 400 :foreground "blue"))))
 '(cider-fringe-good-face ((t (:foreground "#33511c"))))
 '(cider-result-overlay-face ((t (:background "gray80" :foreground "white"))))
 '(font-lock-builtin-face ((t (:foreground "gray30" :bold t))))
 '(highlight-symbol-face ((t (:underline t))))
 '(hl-paren-face ((t nil)) t)
 '(org-ellipsis ((t (:foreground "gray40"))))
 '(whitespace-line ((t (:background nil :foreground "purple"))))
 '(window-divider ((t (:foreground "gray80")))))
