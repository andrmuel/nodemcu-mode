;;; nodemcu-mode.el --- Minor mode for NodeMCU       -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Andreas Müller

;; Author: Andreas Müller <am@0x7.ch>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(defgroup nodemcu nil
  "NodeMCU support."
  :group 'tools)

(defcustom nodemcu-backend "nodemcu-tool"
  "Which backend to use."
  :package-version '(nodemcu . "0.0.1")
  :group 'nodemcu
  :safe (lambda (val) (memq val '("nodemcu-tool" "nodemcu-uploader")))
  :type '(choice (const "nodemcu-tool"     :tag "Use nodemcu-tool (nodejs based).")
                 (const "nodemcu-uploader" :tag "Use nodemcu-uploader (python based).")))

(defcustom nodemcu-port nil
  "Port for interaction with NodeMCU device."
  :package-version '(nodemcu . "0.0.1")
  :group 'nodemcu
  :type 'string)

(defcustom nodemcu-baudrate nil
  "Baud rate for interaction with NodeMCU device."
  :package-version '(nodemcu . "0.0.1")
  :group 'nodemcu
  :type 'integer)

(defcustom nodemcu-default-keybindings nil
  "Whether to create default key bindings.

\\<nodemcu-mode-map>"
  :package-version '(nodemcu . "0.0.1")
  :group 'nodemcu
  :type 'boolean)

;;;###autoload
(define-minor-mode nodemcu-mode
  "Toggle NodeMCU mode.

This mode allows provides interaction with NodeMCU devices."
  ;; The initial value.
  :init-value nil
  ;; The indicator for the mode line.
  :lighter " NodeMCU"
  ;; The minor mode bindings.
  :keymap (when nodemcu-default-keybindings
            (let ((map (make-sparse-keymap)))
              (define-key map (kbd "C-c C-n C-u") 'nodemcu-upload-current-file)
              (define-key map (kbd "C-c C-n C-e") 'nodemcu-run-current-file)
              (define-key map (kbd "C-c C-n C-x") 'nodemcu-remove-current-file)
              (define-key map (kbd "C-c C-n C-d") 'nodemcu-list-devices)
              (define-key map (kbd "C-c C-n C-l") 'nodemcu-list-files)
              (define-key map (kbd "C-c C-n C-f") 'nodemcu-format-device)
              (define-key map (kbd "C-c C-n C-r") 'nodemcu-reset-device)
              (define-key map (kbd "C-c C-n C-s") 'nodemcu-restart-device)
              (define-key map (kbd "C-c C-n C-t") 'nodemcu-terminal)
              map))
  :group 'nodemcu)

(defun nodemcu--get-command (command &optional args)
  "Build base command to invoke nodemcu-tool or nodemcu-uploader.

Builds shell command for given COMMAND and ARGS."
  (let ((prog nodemcu-backend)
        (port (if nodemcu-port
                  (concat " --port " nodemcu-port)
                  ""))
        (baud (if nodemcu-baudrate
                  (concat " --baud " nodemcu-baudrate)
                  "")))
    (concat prog port baud " " command (when args " ") args)))

(defun nodemcu--run-command (command &optional args)
  "Run the given nodecmu COMMAND with ARGS."
  (compile (nodemcu--get-command command args)))

(defun nodemcu-upload-current-file ()
  "Upload the current file to the NodeMCU device."
  (interactive)
  (nodemcu--run-command "upload" (file-name-nondirectory (buffer-file-name))))

(defun nodemcu-run-current-file ()
  "Run the current file (must be available on device)."
  (interactive)
  (nodemcu--run-command (pcase nodemcu-backend
                          ("nodemcu-tool"     "run")
                          ("nodemcu-uploader" "exec"))
                        (file-name-nondirectory (buffer-file-name))))

(defun nodemcu-remove-current-file ()
  "Delete file with file name of current buffer on device."
  (interactive)
  (nodemcu--run-command (pcase nodemcu-backend
                          ("nodemcu-tool"     "remove")
                          ("nodemcu-uploader" "file remove"))
                        (file-name-nondirectory (buffer-file-name))))

(defun nodemcu-list-devices ()
  "List available NodeMCU devices."
  (interactive)
  (pcase nodemcu-backend
    ("nodemcu-tool"     (nodemcu--run-command "devices"))
    ("nodemcu-uploader" (message "command not supported"))))

(defun nodemcu-list-files ()
  "List files on device."
  (interactive)
  (nodemcu--run-command (pcase nodemcu-backend
                          ("nodemcu-tool"     "fsinfo")
                          ("nodemcu-uploader" "file list"))))

(defun nodemcu-format-device ()
  "Format the NodeMCU device.

This will delete all files, but not the NodeMCU firmware itself."
  (interactive)
  (nodemcu--run-command (pcase nodemcu-backend
                          ("nodemcu-tool"     "mkfs --noninteractive") ;; TODO argument not passed as real argument
                          ("nodemcu-uploader" "file format"))))

(defun nodemcu-reset-device ()
  "Reset the NodeMCU device using DTR/RTS."
  (interactive)
  (pcase nodemcu-backend
    ("nodemcu-tool"     (nodemcu--run-command "reset"))
    ("nodemcu-uploader" (message "command not supported"))))

(defun nodemcu-restart-device ()
  "Restart the NodeMCU device using 'node.restart()' command."
  (interactive)
  (pcase nodemcu-backend
    ("nodemcu-tool"     (message "command not supported"))
    ("nodemcu-uploader" (nodemcu--run-command "node restart"))))

(defun nodemcu-terminal ()
  "Start a serial terminal."
  (interactive)
  ;; (ansi-term (nodemcu--get-command "terminal") "*nodemcu-terminal*"))
  (let ((procname "nodemcu-terminal")
        (bufname "*nodemcu-terminal*"))
    (let ((process
           (make-process :name procname
                         :buffer bufname
                         :command (split-string-and-unquote (nodemcu--get-command "terminal")))))
      (with-current-buffer (process-buffer process)
        (display-buffer (current-buffer))
        (require 'shell)
        (declare-function shell-mode "shell")
        (shell-mode)
        (setq-local header-line-format (format "NodeMCU Terminal (port: %s baudrate: %s)" nodemcu-port nodemcu-baudrate))
        (set-process-filter process 'comint-output-filter)))))

(provide 'nodemcu-mode)
;;; nodemcu-mode.el ends here