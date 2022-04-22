;; Define my C code editing style
(defconst vag-c-style
  '((c-basic-offset . 4)
    (c-comment-only-line-offset . 0)
    (c-offsets-alist . ((statement-block-intro . +)
			(knr-argdecl-intro     . 0)
			(substatement-open     . 0)
			(label                 . 0)
			(statement-cont        . c-lineup-math)
			))
    )
  "My C Coding Style")

;; Set "vag" style for indentation of C (and C++ sources)
(add-hook 'c-mode-common-hook
          (function (lambda()
		      (c-add-style "vag" vag-c-style t)
                      (c-set-style "vag")
		      (c-toggle-auto-state   -1)
                      (c-toggle-hungry-state -1)
		      )
		    )
	  )

(add-hook 'find-file-not-found-hooks
          (function (lambda()
                      (if (string= (file-name-extension (buffer-file-name)) 
                                   "c")
                          (insert-file-contents "~/coding/template.c")
                        )
                      (if (string= (file-name-extension (buffer-file-name)) 
                                   "h")
                          (insert-file-contents "~/coding/template.h")
                        )
                      )
                    )
          )
                      
