;;; Creates new frame for each file opened by 'emacsclient'
(add-hook 'server-switch-hook 
          (function
           (lambda ()
             (let (cb)
               (setq cb (current-buffer))
               (switch-to-buffer (other-buffer cb nil))
               (switch-to-buffer-other-frame cb)
               (server-buffer-done cb)
               (switch-to-buffer cb)
               )
             )
           )
          )

;;;; ===== Start emacs server in order to emacsclients can work =====
(server-start)
