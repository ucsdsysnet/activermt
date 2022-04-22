;;===============================================================
;;			Local modes menus
;;===============================================================

(setq gud-local-menu (make-sparse-keymap "Debugger"))
(define-key gud-local-menu [gud-refresh] '("Refresh" . gud-refresh))
(define-key gud-local-menu [gud-down] '("Down" . gud-down))
(define-key gud-local-menu [gud-up] '("Up" . gud-up))
(define-key gud-local-menu [gud-finish] '("Finish" . gud-finish))
(define-key gud-local-menu [gud-cont] '("Continue" . gud-cont))
(define-key gud-local-menu [gud-delete] '("Delete" . gud-remove))
(define-key gud-local-menu [gud-break] '("Break" . gud-break))
(define-key gud-local-menu [gud-tbreak] '("TBreak" . gud-tbreak))
(define-key gud-local-menu [gud-print] '("Print" . gud-print))
(define-key gud-local-menu [gud-goto] '("Go to cursor" . gud-tbreak-and-cont))
(define-key gud-local-menu [gud-step] '("Step" . gud-step))
(define-key gud-local-menu [gud-next] '("Next" . gud-next))

;;; C mode
(add-hook
 'c-mode-hook
 (function
  (lambda()
    (define-key c-mode-map [menu-bar c c-indent-defun] '("Indent function decl" . c-indent-defun))
    (define-key c-mode-map [menu-bar c c-mark-function] '("Mark function" . c-mark-function))
    (define-key c-mode-map [menu-bar gdb] (cons "GDB" gud-local-menu))
   )))

;;; C++ mode
(add-hook
 'c++-mode-hook
 (function
  (lambda()
    (define-key c++-mode-map [menu-bar c c-indent-defun] '("Indent function decl" . c-indent-defun))
    (define-key c++-mode-map [menu-bar c c-mark-function] '("Mark function" . c-mark-function))
    (define-key c++-mode-map [menu-bar gdb] (cons "GDB" gud-local-menu))
   )))


;;; Text mode
(add-hook
 'text-mode-hook
 (function
  (lambda()
    (define-key (current-local-map) [menu-bar Format]
      (cons "Format" (make-sparse-keymap "Format")))
    (define-key (current-local-map) [menu-bar Format text-autofill] 
      '("Switch autofill".  auto-fill-mode))
    (define-key (current-local-map) [menu-bar Format text-enriched] 
      '("Switch enriched mode".  enriched-mode))
    (define-key (current-local-map) [menu-bar Format props] 
      '("Text Properties" . facemenu-menu))
    (define-key (current-local-map) [menu-bar Format text-prefix] 
      '("Set fill prefix" . set-fill-prefix))
    (define-key (current-local-map) [menu-bar Format text-width] 
      '("Set text width" . set-fill-column))
    (define-key (current-local-map) [menu-bar Format left-margin] 
      '("Set left margin" . set-left-margin))
    (define-key (current-local-map) [menu-bar Format text-frp] 
      '("Fill region as paragraph" . fill-region-as-paragraph))
    (define-key (current-local-map) [menu-bar Format text-fr] 
      '("Fill region" . fill-region))
    (define-key (current-local-map) [menu-bar Format text-fp] 
      '("Fill paragraph" . fill-paragraph))
    (define-key (current-local-map) [menu-bar Format text-center] 
      '("Center line" . center-line))
    )))

;;; Info mode
(add-hook
 'Info-mode-hook
 (function
  (lambda ()
    (define-key Info-mode-map [menu-bar Info]
      (cons "Info" (make-sparse-keymap "Info")))
    (define-key Info-mode-map [menu-bar Info Info-exit] '("Exit" . Info-exit))
    (define-key Info-mode-map [menu-bar Info Info-search] 
      '("Search" . Info-search))
    (define-key Info-mode-map [menu-bar Info Info-menu] '("Menu" . Info-menu))
    (define-key Info-mode-map [menu-bar Info Info-dir] 
      '("Directory" . Info-directory))
    (define-key Info-mode-map [menu-bar Info Info-prev] '("Prev" . Info-prev))
    (define-key Info-mode-map [menu-bar Info Info-next] '("Next" . Info-next))
    (define-key Info-mode-map [menu-bar Info Info-up] '("Up"   . Info-up))
    (define-key Info-mode-map [menu-bar Info Info-back] '("Backward" . Info-last))
    (define-key Info-mode-map [menu-bar Info Info-ref] 
      '("Reference" . Info-follow-reference))
    (define-key Info-mode-map [menu-bar Info Info-down] 
      '("Down" . Info-next-preorder))
  )))

;;; Buffer menu mode
(add-hook
 'buffer-menu-mode-hook
 (function
  (lambda ()
    (define-key Buffer-menu-mode-map [menu-bar Operate]
      (cons "Operate" (make-sparse-keymap "Operate")))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-exec] 
      '("Delete (save)" . Buffer-menu-execute))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-dispbuf] 
      '("Display marked bufs" . Buffer-menu-select))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-unmark] 
      '("Unmark" . Buffer-menu-unmark))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-msel] 
      '("Mark for select" . Buffer-menu-mark))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-mdel] 
      '("Mark for delete"   . Buffer-menu-delete))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-msave] 
      '("Mark for save" . Buffer-menu-save))
    (define-key Buffer-menu-mode-map [menu-bar Operate bufmenu-disp] 
      '("Display this buffer" . Buffer-menu-other-window))
  )))

;;; GUD mode
(add-hook
 'gud-mode-hook
 (function
  (lambda()
    (defun gud-tbreak-and-cont (arg)
      "Set temporary break point at current position and continue execution."
      (interactive "p")
      (gud-tbreak arg)
      (gud-cont arg)
    )
    )))

;;; Compilation mode
(add-hook
 'compilation-mode-hook
 (function
  (lambda()
    (define-key compilation-mode-map [menu-bar compilation-menu compilation-goto-error] 
      '("Go to error" . compile-goto-error))
    (define-key compilation-mode-map [menu-bar compilation-menu compilation-prev-file] 
      '("Previous file" . compilation-previous-file))
    (define-key compilation-mode-map [menu-bar compilation-menu compilation-next-file] 
      '("Next file" . compilation-next-file))
    )))

;;; Book-mark list mode
(add-hook
 'bookmark-bmenu-mode-hook
 (function
  (lambda()
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu]
      (cons "Bookmark" (make-sparse-keymap "Bookmark")))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-exec]
      '("Delete marked bookmarks" . Bookmark-menu-execute))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-rename]
      '("Rename" . Bookmark-menu-rename))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-switch]
      '("Select bookmark in other window" . Bookmark-menu-switch-other-window))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-mark-show]
      '("Show/hide file names" . Bookmark-menu-toggle-filenames))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-mark-select]
      '("Select bookmarks" . Bookmark-menu-select))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-mark-unmark]
      '("Unmark" . Bookmark-menu-unmark))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-mark-for-delete]
      '("Mark for delete" . Bookmark-menu-delete))
    (define-key bookmark-bmenu-mode-map [menu-bar compilation-menu book-mark-mark-for-display]
      '("Mark for display" . Bookmark-menu-mark))
    )))


;;;; Add some items to the menu bar

;;; Additional items to Search menu
(define-key menu-bar-search-menu [tag-search]
  '("Tag search..." . tags-search))
(define-key menu-bar-search-menu [tag-replace] 
   '("Tag replace..." . tags-query-replace))
(define-key menu-bar-search-menu [tag-continue] 
   '("Repeat tag search..." . tags-loop-continue))

;;; Additional items to Tools menu
(define-key menu-bar-tools-menu [run-shell] '("Shell" . shell))
(define-key menu-bar-tools-menu [run-shell-command] '("Shell command" . shell-command))
(define-key menu-bar-tools-menu [run-gdb] '("GDB" . gdb))
(define-key menu-bar-tools-menu [make] '("Compile" . compile))
(define-key menu-bar-tools-menu [separator-make]  '("--"))

;;; Additional items to Edit menu
(define-key menu-bar-edit-menu  [edit-sep-r] '("--"))
(define-key menu-bar-edit-menu  [edit-open-r] '("Open rectangle" . delete-rectangle))
(define-key menu-bar-edit-menu  [edit-clear-r] '("Clear rectangle" . delete-rectangle))
(define-key menu-bar-edit-menu  [edit-paste-r] '("Paste rectangle" . yank-rectangle))
(define-key menu-bar-edit-menu  [edit-cut-r] '("Cut rectangle" . kill-rectangle))
(define-key menu-bar-edit-menu  [edit-mark-sep] '("--"))
(define-key menu-bar-edit-menu  [edit-yank-pop] '("Paste next" . yank-pop))
(define-key menu-bar-edit-menu  [edit-mark] '("Mark" . set-mark-command))
(define-key menu-bar-edit-menu  [edit-swap] '("Swap point and mark". exchange-dot-and-mark))
(define-key menu-bar-edit-menu  [edit-unmark] '("Cancel mark" . cancel-mark))

;;; Window menu
(setq menu-bar-window-menu (make-sparse-keymap "Window"))
(define-key global-map [menu-bar window] 
   (cons " Window" menu-bar-window-menu))

(define-key menu-bar-window-menu [split-win-v] 
   '("Split window vertically" . split-window-vertically))

(define-key menu-bar-window-menu [split-win-h] 
   '("Split window horizontally" . split-window-horizontally))

(define-key menu-bar-window-menu [shrink-win] 
   '("Shrink window" . shrink-window))

(define-key menu-bar-window-menu [enrlage-win] 
   '("Enlarge window" . enlarge-window))

(define-key menu-bar-window-menu [delete-other-win] 
   '("Maximize" . delete-other-windows))

(define-key menu-bar-window-menu [delete-win] 
   '("Delete window" . delete-window))


;;; Macro menu
(setq menu-bar-macro-menu (make-sparse-keymap "Macro"))
(define-key global-map [menu-bar macro] 
   (cons " Macro" menu-bar-macro-menu))

(define-key menu-bar-macro-menu [edit-macro] 
   '("Edit macro" . edit-kbd-macro))

(define-key menu-bar-macro-menu [end-macro] 
   '("End macro" . end-kbd-macro))

(define-key menu-bar-macro-menu [start-macro] 
   '("Start macro" . start-kbd-macro))

(define-key menu-bar-macro-menu [call-macro] 
   '("Call macro" . call-last-kbd-macro))
