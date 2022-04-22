;;; Print the line number on the status line
(setq line-number-mode 1)

;;; Add column number to mode-line format.
(setq  default-mode-line-format (list
           '""
           'mode-line-modified
           'mode-line-buffer-identification
           '"   "
           'global-mode-string
           '"   %[("
           'mode-name
           'mode-line-process
           'minor-mode-alist
           '"%n"
           '")%]----"
           '(line-number-mode "%l:%c--")
           '(-3 . "%p")
           '"-%-")
       )
