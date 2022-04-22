;;===============================================================
;;			Local modes key binding
;;===============================================================

;;; C mode
(add-hook
 'c-mode-hook
 (function
  (lambda()
    (define-key c-mode-map [?\A-\ ]         'mark-c-function)                  ; A-SPC
    (define-key c-mode-map [A-home]         'c-beginning-of-statement)         ; A-home
    (define-key c-mode-map [A-end]          'c-end-of-statement)               ; A-end
    (define-key c-mode-map [A-kp-7]         'c-beginning-of-statement)         ; A-home
    (define-key c-mode-map [A-kp-1]         'c-end-of-statement)               ; A-end
    (define-key c-mode-map [C-tab]          'c-indent-defun)                   ; C-TAB
    (define-key c-mode-map [A-tab]          'c-indent-exp)                     ; A-TAB
   )))

;;; C++ mode
(add-hook
 'c++-mode-hook
 (function
  (lambda()
    (define-key c++-mode-map [return]         'reindent-then-newline-and-indent) ; Enter
    (define-key c++-mode-map [?\A-\ ]         'mark-c-function)                  ; A-SPC
    (define-key c++-mode-map [A-home]         'c-beginning-of-statement)         ; A-home
    (define-key c++-mode-map [A-end]          'c-end-of-statement)               ; A-end
    (define-key c++-mode-map [A-kp-7]         'c-beginning-of-statement)         ; A-home
    (define-key c++-mode-map [A-kp-1]         'c-end-of-statement)               ; A-end
    (define-key c++-mode-map [C-tab]          'c-indent-defun)                   ; C-TAB
    (define-key c++-mode-map [A-tab]          'c-indent-exp)                     ; A-TAB
   )))


;;; Text mode
(add-hook
 'text-mode-hook
 (function
  (lambda()
    ; (auto-fill-mode 1)
    (define-key text-mode-map [f11]       'center-line)                 ; F11
    (define-key text-mode-map [f12]       'fill-paragraph)              ; F12
    (define-key text-mode-map [C-f12]     'fill-region-as-paragraph)    ; C-F12
    (define-key text-mode-map [S-f12]     'fill-region)                 ; S-F12
    (define-key text-mode-map [S-f11]     'set-fill-column)             ; S-F11
    (define-key text-mode-map [M-f11]     'set-fill-prefix)             ; M-F11
    (define-key text-mode-map [A-f11]     'set-left-margin)             ; A-F11
    )))

;;; Info mode
(add-hook
 'Info-mode-hook
 (function
  (lambda () nil
  )))

;;; Buffer menu mode
(add-hook
 'buffer-menu-mode-hook
 (function
  (lambda () nil
  )))

;;; ISearch mode
(define-key isearch-mode-map [f12]          (cons isearch-mode-map ?\C-S)) ; Find
(define-key isearch-mode-map [S-f12]        (cons isearch-mode-map ?\C-R)); S-Find

;;; Compilation mode
(add-hook
 'compilation-mode-hook
 (function
  (lambda()
    (define-key compilation-mode-map [f7]           'compilation-next-file)      ; F7
    (define-key compilation-mode-map [S-f7]         'compilation-previous-file)  ; S-F7
    (define-key compilation-mode-map [return]       'compile-goto-error)         ; Enter
    )))

;;; Book-mark list mode
(add-hook
 'bookmark-bmenu-mode-hook
 (function
  (lambda() nil
    )))

;;;;===============================================================
;;;;			Global key binding
;;;;===============================================================

;;; Right keypad
(define-key global-map [kp-divide]   'delete-whole-line) ; </> 
(define-key global-map [kp-multiply] 'copy-and-unmark)   ; <*> 
(define-key global-map [kp-subtract] 'kill-region)       ; <->
(define-key global-map [kp-add]      'yank)	         ; <+>
(define-key global-map [kp-7]        'beginning-of-line) ; home
(define-key global-map [C-kp-7]      'backward-page)     ; C-Home
(define-key global-map [M-kp-7]      'start-kbd-macro)   ; M-Home
(define-key global-map [kp-8]        'previous-line)     ; up
(define-key global-map [C-kp-8]      'scroll-down-one)   ; C-up
(define-key global-map [kp-9]        'window-up)         ; PgUp
(define-key global-map [C-kp-9]      'beginning-of-buffer)  ; C-PgUp
(define-key global-map [kp-4]        'backward-char)     ; left
(define-key global-map [C-kp-4]      'backward-token)    ; C-left
(define-key global-map [A-kp-4]      'backward-sexp)     ; A-left
(define-key global-map [kp-0]        'overwrite-mode)    ; Ins

;; (define-key global-map [kp-5]   'russian-insertion-mode) ; kp-5
(define-key global-map [kp-6]        'forward-char)      ; right
(define-key global-map [C-kp-6]      'forward-token)     ; C-right
(define-key global-map [A-kp-6]      'forward-sexp)      ; A-right
(define-key global-map [C-kp-6]      'forward-page)      ; C-End
(define-key global-map [kp-1]        'end-of-line)       ; End
(define-key global-map [M-kp-1]      'end-kbd-macro)     ; M-End
(define-key global-map [kp-2]        'next-line)         ; down
(define-key global-map [C-kp-2]      'scroll-up-one)     ; C-down
(define-key global-map [kp-3]        'window-down)       ; PgDn
(define-key global-map [C-kp-3]      'end-of-buffer)     ; C-PgDn

(define-key global-map [kp-decimal]  'delete-char)   	        ; DEL
(define-key global-map [M-kp-decimal] 'kill-word)   	        ; M-DEL
(define-key global-map [kp-enter]    'execute-extended-command) ; Enter


;;; Middle keypad
(define-key global-map [home]          'beginning-of-line)   ; Home
(define-key global-map [C-home]        'backward-page)       ; C-Home
(define-key global-map [M-home]        'start-kbd-macro)     ; M-Home
(define-key global-map [up]            'previous-line)       ; up
(define-key global-map [C-up]          'scroll-down-one)     ; C-up
(define-key global-map [prior]         'window-up)           ; PgUp
(define-key global-map [C-prior]       'beginning-of-buffer) ; C-PgUp
(define-key global-map [left]          'backward-char)       ; left
(define-key global-map [C-left]        'backward-token)      ; C-left
(define-key global-map [A-left]        'backward-sexp)       ; A-left
(define-key global-map [right]         'forward-char)        ; right
(define-key global-map [C-right]       'forward-token)       ; C-right
(define-key global-map [A-right]       'forward-sexp)        ; A-right
(define-key global-map [down]          'next-line)           ; down
(define-key global-map [C-down]        'scroll-up-one)       ; C-down
(define-key global-map [end]           'end-of-line)         ; End
(define-key global-map [C-end]         'forward-page)        ; C-End
(define-key global-map [M-end]         'end-kbd-macro)       ; M-End
(define-key global-map [next]          'window-down)         ; PgDn
(define-key global-map [C-next]        'end-of-buffer)       ; C-PgDn
(define-key global-map [insert]        'overwrite-mode)      ; Ins
(define-key global-map [delete]        'delete-char)   	     ; DEL
(define-key global-map [M-delete]      'kill-word)   	     ; M-DEL


;;; Function keys
(define-key global-map [f1]            'manual-entry)        ; F1
(define-key global-map [f2]            'save-buffer)	     ; F2
(define-key global-map [C-f2]          'save-some-buffers)   ; C-F2
(define-key global-map [f3]            'find-file)	     ; F3
(define-key global-map [S-f3]          'reread-file)	     ; S-F3
(define-key global-map [S-f4]          'shell-command)             ; S-F4
(define-key global-map [C-S-f4]        'shell)                     ; C-S-F4
(define-key global-map [f5]            'delete-other-windows)      ; F5
(define-key global-map [f6]            'kill-buffer-delete-window) ; F6
(define-key global-map [f8]            'next-error)		   ; F8
(define-key global-map [f9]            'compile)	           ; F9
(define-key global-map [C-f9]          'gdb)	        	   ; C-F9
(define-key global-map [f10]           'kill-buffer)	           ; F10
(define-key global-map [f11]           'repeat-complex-command)    ; F11
(define-key global-map [f12]           'isearch-forward)           ; F12

(define-key global-map [print]         'list-buffers)              ; Print Screen
(define-key global-map [pause]         'advertised-undo)           ; Pause


;; Function keys for GUD
(define-key global-map [f7]            'gud-next)                  ; F7
(define-key global-map [S-f7]          'gud-step)                  ; S-F7
(define-key global-map [f4]            'gud-tbreak-and-cont)       ; F4
(define-key global-map [C-f4]          'gud-print)                 ; C-F4
(define-key global-map [C-f8]          'gud-tbreak)                ; C-F8
(define-key global-map [S-f8]          'gud-break)                 ; S-F8
(define-key global-map [C-S-f8]        'gud-remove)                ; C-S-F8
(define-key global-map [S-f9]          'gud-cont)                  ; S-F9
(define-key global-map [M-f9]          'gud-finish)                ; M-F9
(define-key global-map [A-up]          'gud-up)                    ; A-up
(define-key global-map [A-down]        'gud-down)                  ; A-down


;;; Main keyboard
(define-key global-map [C-return]     'call-last-kbd-macro)   	    ; C-Return
(define-key global-map [S-C-return]   'apply-macro-to-region-lines) ; S-C-Return
(define-key global-map [?\C-L]        'recenter-and-fontify)        ; ^L
(define-key global-map [C-down-mouse-1] 'mouse-buffer-menu)         ;
(define-key global-map [S-down-mouse-3] 'imenu)                     ;
(define-key global-map [S-down-mouse-2] 'mouse-set-font)            ;
