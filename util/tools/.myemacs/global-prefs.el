;; Set up the keyboard so the delete key on both the regular keyboard
;; and the keypad delete the character under the cursor and to the right
;; under X, instead of the default, backspace behavior.
(global-set-key [delete] 'delete-char)
(global-set-key [kp-delete] 'delete-char)

;; Turn on font-lock mode for Emacs
(cond ((not running-xemacs) (global-font-lock-mode t)))
(setq font-lock-maximum-decoration t)

;; Always end a file with a newline
(setq require-final-newline t)

;; Stop at the end of the file, not just add lines
(setq next-line-add-newlines nil)

;;; Don't use TAB character for indentation
(setq-default indent-tabs-mode nil)

;;; Set default text width to 78
(setq-default fill-column 78)

;;; Enable region highlighting
(setq transient-mark-mode t)

;;; Enable highlighting of matched text during query-replace
(setq query-replace-highlight t)

;;; Enable highlighting of matched text during incremental-search
(setq search-highlight t)

; Set "paren" face to underline 
(setq show-paren-face 'underline)

;;; Backup control
(setq backup-by-copying-when-linked t)
(setq version-control 'never)     
(setq trim-versions-without-asking t)  

;; Save cursor position between editing sessions
(setq-default save-place t)

;; Nice buffer menu
(msb-mode)

;;; Use indented-text-mode as default mode
(setq default-major-mode 'indented-text-mode)

;;; The number of lines to try scrolling a window by when point moves out
(setq scroll-step 1)

;;; Window title to reflect the file
(setq frame-title-format "%b")
