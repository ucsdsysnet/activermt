(defvar keyboard-settings-alist
  '(("sun_type_4" . "sun4-kbd")
    ("sun_type_5" . "sun5-kbd")
    ("pc_like" . "pc-kbd")
    ("hp" . "hp-kbd"))
  "   Alist of emacs keyboard settings types. 
Key is keyboard type name, value - elisp file containing keybindings.")

(defun keyboard-type-resource ()
  "Returns value of 'keyboard_type' X resource."
  (x-get-resource "keyboard_type" ""))

(defun load-keyboard-settings ()
  "   Determine keyboard type (from X server resource 'keyboard_type'),
and load file containing keyboard specific keybindings."
  (let* ((keyboard-type (keyboard-type-resource))
         keyboard-settings-file)
    (if (not keyboard-type)
        (message 
         "Not specified 'keyboard_type' resource. Try 'set-keyboard-type' command.")
      (progn
        (setq keyboard-settings-file
              (cdr (assoc keyboard-type keyboard-settings-alist)))
        (if (not keyboard-settings-file)
            (message
             "Unknown 'keyboard_type' resource value. Try 'set-keyboard-type' command.")
          (load keyboard-settings-file))
        ))
    ))

(defun set-keyboard-type ()
  "   Load file with keyboard specific keybindings."
  (interactive)
  (let* ((type 
          (completing-read "Keyboard type: " keyboard-settings-alist nil t)))
    (if (not (eq type "")) (load (cdr (assoc type keyboard-settings-alist))))))

(load-keyboard-settings)
(load "new-Xmenus")
