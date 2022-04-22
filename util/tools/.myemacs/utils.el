;;;;===============================================================
;;;;			 Some Utilities
;;;;===============================================================


;; From Jeff Peck, Sun Microsystems Inc  <peck@sun.com>

(defun scroll-down-in-place (n)
  (interactive "p")
  (previous-line n)
  (scroll-down n))

(defun scroll-up-in-place (n)
  (interactive "p")
  (next-line n)
  (scroll-up n))


;; From AO 

(defun convert-buffer-to-koi8 ()
  "Convert characters in buffer from 
Alternative (MS-DOS) charset to KOI-8 (Unix) charset. 
Actually, `convert' utility is used in shell command on region.
Works even on read-only buffers."
  (interactive)
  (let  ((buffer-read-only nil))
    (mark-whole-buffer)
    (shell-command-on-region (region-beginning) (region-end) "convert -u -l" 1 1)
    (not-modified)
    ))

(defun convert-buffer-to-alt ()
  "Convert characters in buffer from 
KOI-8 (Unix) charset to Alternative (MS-DOS) charset. 
Actually, `convert' utility is used in shell command on region.
Works even on read-only buffers."
  (interactive)
  (let  ((buffer-read-only nil))
    (mark-whole-buffer)
    (shell-command-on-region (region-beginning) (region-end) "convert -d -l" 1 1)
    (not-modified)
    ))

(defun info-other-frame()
  (interactive)
  (new-frame)
  (info)
  )


;;;; ======================================================================

(defun frame-x (fr)
  "Returns X coordinate of top-left corner of the frame fr."
  (cdr (assq 'left (frame-parameters fr)))
)

(defun frame-y (fr)
  "Returns Y coordinate of top-left corner of the frame fr."
  (cdr (assq 'top (frame-parameters fr)))
)


(defun kill-frame ()
  "Remove current buffer and current frame."
  (interactive)
  (let (cb fr)
   (setq cb (current-buffer))
   (server-buffer-done cb)
   (kill-buffer cb)
  )
  (if (cdr (frame-list))
   (delete-frame) 
   (iconify-frame)
  )
)

(defun delete-whole-line ()
 "Delete whole line."
 (interactive)
 (let
  ((col (current-column))
   (p))
  (forward-line 0)
  (setq p (point))
  (forward-line 1)
  (delete-region p (point))
  (move-to-column col)
 )
)

(defun current-line ()
  "Return the vertical position of point in the selected window.  
   Top line is 0.  Counts each text line only once, even if it wraps."
  (+ (count-lines (window-start) (point))
     (if (= (current-column) 0) 1 0)
   -1))

(defun window-up () 
  "This function scrolls the text in the selected window upward
     'window-height' lines."
  (interactive)
  (let '(cl (current-line))
    (previous-line (- (window-height) 1 next-screen-context-lines))
    (recenter cl)
  )
)

(defun window-down () 
  "This function scrolls the text in the selected window downward
     'window-height' lines."
  (interactive)
  (let '(cl (current-line))
    (next-line (- (window-height) 1 next-screen-context-lines))
    (recenter cl)
  )
)

(defun forward-token ()
  "Move point right to the next symbol or identifier."
  (interactive)
  (condition-case nil
    (progn  
      (if (looking-at "[a-zA-Z_0-9\200-\377]")
        (progn 
          (re-search-forward "[^a-zA-Z_0-9\200-\377]")
          (backward-char)
        )
        (if (looking-at "[^ 	a-zA-Z_0-9\200-\377]")
           (forward-char)
        )
      )
      (re-search-forward "[^ 	]")
      (backward-char)
    )
    (error (signal 'end-of-buffer nil))
  )
)

(defun backward-token ()
  "Move point left to the previous symbol or identifier."
  (interactive)
  (condition-case nil
    (progn  
      (re-search-backward "[^ 	]")
      (if (looking-at "[a-zA-Z_0-9\200-\377]")
         (progn 
           (re-search-backward "[^a-zA-Z_0-9\200-\377]")
           (forward-char)
         )
      )
    )
    (error (signal 'beginning-of-buffer nil))
  )
)

(defun kill-buffer-delete-window ()
 "Kill current buffer and delete current window"
 (interactive)
 (kill-buffer (current-buffer))
 (delete-window)
)

(defun scroll-down-one ()
 "Scroll 1 line down."
 (interactive)
 (scroll-down 1)
)

(defun scroll-up-one ()
 "Scroll 1 line up."
 (interactive)
 (scroll-up 1)
)

(defun cancel-mark ()	 
  (interactive)		 
  (setq deactivate-mark t)
)	        	 
	        	 
(defun copy-and-unmark (beg end)
  (interactive "r")	 
  (copy-region-as-kill beg end)
  (setq deactivate-mark t)
)	     
	     
(defun justify-paragraph ()
  (interactive)
  (fill-paragraph 1)
)

(defun justify-region (from to)
  (interactive "r")
  (fill-region from to 1)
)

(defun justify-region-as-paragraph (from to)
  (interactive "r")
  (fill-region-as-paragraph from to 1)
)

(defun reread-file ()
  (interactive)
  (insert-file-contents buffer-file-name t nil nil t)
)

(defun recenter-and-fontify ()
  (interactive)
  (recenter)
  (if (fboundp 'font-lock-fontify-buffer)
      (font-lock-fontify-buffer))
)
