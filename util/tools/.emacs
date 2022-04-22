;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; .emacs
;
; This is my Emacs initialization file. For now I know that it only works
; with Emacs, not Xemacs
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; I am going to put my initialization code in ~/.myemacs directory

;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
(package-initialize)

(setq load-path (append '("~/.myemacs") load-path))

;; Are we running XEmacs or Emacs?
(defvar running-xemacs (string-match "XEmacs\\|Lucid" emacs-version))

;; Load useful emacs modules
;;;(load "s-region")           ;;; Enable marking by SHIFT+motion
(load "paren")              ;;; Highlight whatever paren matches
(load "saveplace")          ;;; Save cursor position between editing sessions
;;;(load "verilog-mode")       ;;; Verilog language mode
(load "xcscope")            ;; Cscope support
(load "p4-mode")            ;; P4 lanuage mode
(load "yaml-mode")
(load "protobuf-mode")

;; Now, load my stuff
(load "global-prefs")
(load "status-line")
(load "file-types")
(load "c-mode-prefs")

;; Start Emacs Server
;; (load "emacs-server")

;; Load keyboard bindings and menus
(load "new-Xmenus")
(load "utils")
(load "pc-kbd")

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-names-vector
   ["#242424" "#e5786d" "#95e454" "#cae682" "#8ac6f2" "#333366" "#ccaa8f" "#f6f3e8"])
 '(custom-enabled-themes (quote (adwaita)))
 '(inhibit-startup-screen t)
 '(line-number-mode 1)
 '(safe-local-variable-values (quote ((p4-version . 14))))
 '(show-trailing-whitespace t)
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(autoload 'markdown-mode "markdown-mode"
   "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))

(autoload 'gfm-mode "markdown-mode"
   "Major mode for editing GitHub Flavored Markdown files" t)
(add-to-list 'auto-mode-alist '("README\\.md\\'" . gfm-mode))
(put 'upcase-region 'disabled nil)
