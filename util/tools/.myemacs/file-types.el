;;; Association list of filename patterns vs corresponding major mode 
;;; functions. 
(setq auto-mode-alist
      (append '(
                ("[Mm]akefile.*"    . makefile-mode)
                (".*[.]mk"          . makefile-mode)
                (".*[.]h"           . c-mode)
                ("p4[-_]?14.*[.]p4" . p4_14-mode)
                ("p4[-_]?16.*[.]p4" . p4_16-mode)
                ("p4include.*[.]p4" . p4_16-mode)
                (".*[.]p4"          . p4_16-mode)
		(".*[.]v"           . verilog-mode)
                ("[.].*emacs[.].*"  . emacs-lisp-mode)
                (".*[.]bfa"         . yaml-mode)
                (".*[.]yaml"        . yaml-mode)
                (".*[.]proto"       . protobuf-mode)
                )
              auto-mode-alist
              )
      )
