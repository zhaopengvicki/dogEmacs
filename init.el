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
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-faces-vector
   [default default default italic underline success warning error])
 '(ansi-color-names-vector
   ["#272822" "#F92672" "#A6E22E" "#E6DB74" "#66D9EF" "#FD5FF0" "#A1EFE4" "#F8F8F2"])
 '(ansi-term-color-vector
   [unspecified "#2e2e2e" "#bc8383" "#7f9f7f" "#d0bf8f" "#6ca0a3" "#dc8cc3" "#8cd0d3" "#b6b6b6"])
 '(compilation-message-face (quote default))
 '(cua-global-mark-cursor-color "#2aa198")
 '(cua-normal-cursor-color "#839496")
 '(cua-overwrite-cursor-color "#b58900")
 '(cua-read-only-cursor-color "#859900")
 '(custom-safe-themes
   (quote
    ("8db4b03b9ae654d4a57804286eb3e332725c84d7cdab38463cb6b97d5762ad26" default)))
 '(fci-rule-color "#3C3D37")
 '(highlight-changes-colors (quote ("#FD5FF0" "#AE81FF")))
 '(highlight-symbol-colors
   (--map
    (solarized-color-blend it "#002b36" 0.25)
    (quote
     ("#b58900" "#2aa198" "#dc322f" "#6c71c4" "#859900" "#cb4b16" "#268bd2"))))
 '(highlight-symbol-foreground-color "#93a1a1")
 '(highlight-tail-colors
   (quote
    (("#3C3D37" . 0)
     ("#679A01" . 20)
     ("#4BBEAE" . 30)
     ("#1DB4D0" . 50)
     ("#9A8F21" . 60)
     ("#A75B00" . 70)
     ("#F309DF" . 85)
     ("#3C3D37" . 100))))
 '(hl-bg-colors
   (quote
    ("#7B6000" "#8B2C02" "#990A1B" "#93115C" "#3F4D91" "#00629D" "#00736F" "#546E00")))
 '(hl-fg-colors
   (quote
    ("#002b36" "#002b36" "#002b36" "#002b36" "#002b36" "#002b36" "#002b36" "#002b36")))
 '(kaolin-hl-line-colored t)
 '(magit-diff-use-overlays nil)
 '(package-selected-packages
   (quote
    (easy-kill undo-tree creamsody-theme anzu dracula-theme solarized-theme zenburn-theme flycheck-pos-tip flycheck-clojure dummy-package dummyparens parenface parenface2 parenface-plus goose-theme grayscale-theme hl-sexp feebleline feebleline-mode leuven-theme ert-expectations spacemacs-theme monokai-theme color-theme-monokai color-theme-solarized use-package telephone-line restclient rainbow-delimiters parinfer org-plus-contrib org-bullets neotree magit kaolin-themes hugsql-ghosts highlight-symbol highlight-parentheses hideshowvis git-gutter-fringe+ git-gutter expand-region exec-path-from-shell diminish counsel-projectile company color-theme-zenburn clj-refactor ag ace-window)))
 '(pos-tip-background-color "#FFFACE")
 '(pos-tip-foreground-color "#272822")
 '(smartrep-mode-line-active-bg (solarized-color-blend "#859900" "#073642" 0.2))
 '(term-default-bg-color "#002b36")
 '(term-default-fg-color "#839496")
 '(tramp-syntax (quote default) nil (tramp))
 '(vc-annotate-background nil)
 '(vc-annotate-background-mode nil)
 '(vc-annotate-color-map
   (quote
    ((20 . "#F92672")
     (40 . "#CF4F1F")
     (60 . "#C26C0F")
     (80 . "#E6DB74")
     (100 . "#AB8C00")
     (120 . "#A18F00")
     (140 . "#989200")
     (160 . "#8E9500")
     (180 . "#A6E22E")
     (200 . "#729A1E")
     (220 . "#609C3C")
     (240 . "#4E9D5B")
     (260 . "#3C9F79")
     (280 . "#A1EFE4")
     (300 . "#299BA6")
     (320 . "#2896B5")
     (340 . "#2790C3")
     (360 . "#66D9EF"))))
 '(vc-annotate-very-old-color nil)
 '(weechat-color-list
   (unspecified "#272822" "#3C3D37" "#F70057" "#F92672" "#86C30D" "#A6E22E" "#BEB244" "#E6DB74" "#40CAE4" "#66D9EF" "#FB35EA" "#FD5FF0" "#74DBCD" "#A1EFE4" "#F8F8F2" "#F8F8F0"))
 '(xterm-color-names
   ["#073642" "#dc322f" "#859900" "#b58900" "#268bd2" "#d33682" "#2aa198" "#eee8d5"])
 '(xterm-color-names-bright
   ["#002b36" "#cb4b16" "#586e75" "#657b83" "#839496" "#6c71c4" "#93a1a1" "#fdf6e3"]))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
