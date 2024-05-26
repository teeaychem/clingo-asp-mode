;;; clingo-asp-mode.el ---- A major mode for editing clingo ASP files. -*- lexical-binding: t -*-

;;; Commentary:

;; no commentary for the moment

;;; Code:
(defgroup clingo-asp nil
  "Commands used by `clingo-asp-mode'."
  :group 'clingo-asp)


;; general defcustoms
(defcustom clingo-asp-mode-version "0.0.1"
  "Version of `clingo-asp-mode'."
  :type 'string
  :group 'clingo-asp)

(defcustom clingo-asp-clingo-executable (executable-find "clingo")
  "Path to clingo binary used for execution."
  :type 'string
  :group 'clingo-asp)


(defcustom clingo-asp-gringo-executable (executable-find "gringo")
  "Path to gringo binary used for execution."
  :type 'string
  :group 'clingo-asp)

(defcustom clingo-asp-indentation 2
  "Level of indentation."
  :type 'integer
  :group 'clingo-asp)
;; general defcustoms end


;; exit code start
(defconst clingo-asp-exit-codes
  '((128 "E_NO_RUN" "Search not started because of syntax or command line error.")
    (65 "E_ERROR" "Run was interrupted by internal error.")
    (33 "E_MEMORY" "Run was interrupted by out of memory exception.")
    (20 "E_EXHAUST" "Search-space was completely examined.")
    (10 "E_SAT" "At least one model was found.")
    (1 "E_INTERRUPT" "Run was interrupted.")
    (0 "E_UNKNOWN" "Satisfiablity of problem not known; search not started.")))


(defun clingo-asp-decode-exit (code)
  "Decode CODE into a list of base codes."
  ;; see https://github.com/potassco/clasp/issues/42#issuecomment-459981038%3E
  (let ((decomposed '()))
    (defun process-code (number)
      (setq code (- code number))
      (setq decomposed (cons number decomposed)))
    (if (= code 0) (process-code 0))
    (if (>= code 128) (process-code 128))
    (if (>= code 65) (process-code 65))
    (if (>= code 33) (process-code 33))
    (if (>= code 20) (process-code 20))
    (if (>= code 10) (process-code 10))
    (if (>= code 1) (process-code 1))
    (clingo-asp-codes-to-string decomposed)))


(defun clingo-asp-codes-to-string (codes)
  "Return a summary string of CODES."
  (let* ((code-sym (string-join (mapcar (lambda (x) (cadr (assoc x clingo-asp-exit-codes))) codes)" + "))
         (code-exp (string-join (mapcar (lambda (x) (caddr (assoc x clingo-asp-exit-codes))) codes) " ")))
    (format "%s (%s)" code-sym code-exp)))


(defun clingo-asp-clingo-process-exit (process-name)
  "Use with `set-process-sentinel' to perform actions after PROCESS-NAME exits."
  (lambda (process event)
    (let ((process-buffer (get-buffer process-name)))
      (with-current-buffer process-buffer
            (special-mode)
            (goto-char (point-min)))
      (if (and (> (length event) 27)
               (equal (substring event 0 27) "exited abnormally with code"))
          (princ (format "Process: %s exited with: %s" process (clingo-asp-decode-exit (string-to-number (car (last (split-string event)))))))))))


(defun clingo-asp-gringo-process-exit (process-name)
  "Use with `set-process-sentinel' to perform actions after PROCESS-NAME exits."
  (lambda (process event)
    (let ((process-buffer (get-buffer process-name)))
      (if (not (string-equal "finished" event))
          (message (format "Process: %s: %s" process event)))
      (with-current-buffer process-buffer
        (special-mode)
        (goto-char (point-min))))))
;; exit code end



;; choosing arguments
(defvar clingo-asp-arguments-list
  '((:name "vanilla"
     :interactive nil
     :commands ()
     :help "no arguments")
    (:name "all models"
     :interactive nil
     :commands ("--models=0")
     :help "")
    (:name "all subset minimal models"
     :interactive nil
     :commands ("--models=0" "--enum-mode=domRec" "--heuristic=Domain" "--dom-mod=5,16")
     :help "")
    (:name "custom"
     :interactive t
     :commands (string-split (read-string "Commands:"))
     :help "enter commands in a prompt")
    (:name "n models"
     :interactive t
     :commands  (string-split (format "--models=%s" (read-string "Number of models:")))
     :help "--models=(prompt: n)")
    (:name "help"
     :interactive nil
     :commands  ("--help")
     :help "")))


(defcustom clingo-asp-arguments-help-separator "  "
  "String used to separate argument name from help.
Used when interactively choosing arguments."
  :type 'string
  :group 'clingo-asp)


(defun clingo-asp-annotate-command (command)
  "Get annotation for COMMAND.
Used in `clingo-asp-arguments-query'."
  (concat clingo-asp-arguments-help-separator (clingo-asp-get-args-or-help clingo-asp-arguments-list command)))


(defun clingo-asp-get-args-or-help (command-list command)
  "Helper for `clingo-asp-annotate-command'.
If COMMAND-LIST contains plists with :name, :commands, and :help,
 reutrn :help if non-empty and otherwise :commands when :name is COMMAND."
  (if (eq command-list '())
      ""
    (if (string-equal command (plist-get (car command-list) ':name))
        (let ((help-string (plist-get (car command-list) ':help)))
          (if (string-equal help-string "")
              (string-join (plist-get (car command-list) ':commands) " ")
            help-string))
      (clingo-asp-get-args-or-help (cdr command-list) command))))
;; choosing arguments end



;; calling programs

;; ;; helpers
(defun clingo-asp-arguments-query ()
  "Query user for arguments to pass to clingo."
  (let* ((default "Vanilla")
         (completion-ignore-case t)
         (completion-extra-properties '(:annotation-function clingo-asp-annotate-command))
         (command-plist-list (mapcar (lambda (x) (cons (plist-get x ':name) x)) clingo-asp-arguments-list))
         (answer (completing-read
                  (concat "Command (default " default "): ")
                  command-plist-list nil t
                  nil nil default)))
    (let* ((the-plist (cdr (assoc answer command-plist-list)))
           (the-commands (plist-get the-plist ':commands))
           (eval-required (plist-get the-plist ':interactive)))
      (if eval-required
          (eval the-commands)
        the-commands))))

(defun clingo-asp-interactively-get-file-list (file)
  "A list of interactively chosen FILEs.
Choosing anything other than an existing file ends choice.
E.g. if `done' is not a file choose `done' to return the list."
  (interactive "F")
  (if (file-exists-p file)
      (cons file (call-interactively #'clingo-asp-interactively-get-file-list))
    (list )))
;; ;; helpers end


(defun clingo-asp-call-clingo (files args)
  "Run clingo on FILES with ARGS as a new process with it's own buffer."
  (let* ((args-files (append args (mapcar #'file-truename files)))
         (clingo-process (generate-new-buffer-name "*clingo*"))
         (clingo-buffer (get-buffer-create clingo-process)))
    (apply #'make-process
           (list :name clingo-process
                 :buffer clingo-buffer
                 :command (cons clingo-asp-clingo-executable args-files)
                 :sentinel (clingo-asp-clingo-process-exit clingo-process)))
    (pop-to-buffer clingo-buffer)))


(defun clingo-asp-call-clingo-on-current-buffer ()
  "Call `clingo-asp-call-clingo-choice' on the file opened in the current buffer."
  (interactive)
  (let ((this-file (buffer-file-name)))
    (clingo-asp-call-clingo-choice (list this-file))))


(defun clingo-asp-call-clingo-on-current-region (start end)
  "Run clingo on the region from START to END."
  (interactive "r")
  (let ((temp-file (make-temp-file "clingo-region" nil ".lp" nil)))
    (write-region start end temp-file t)
    (clingo-asp-call-clingo-choice (list temp-file))))


(defun clingo-asp-call-clingo-choice (files)
  "Call `clingo-asp-call-clingo' on FILES with chosen arguments."
  (clingo-asp-call-clingo files (clingo-asp-arguments-query)))


(defun clingo-asp-call-clingo-file-choice (file)
  "Call `clingo-asp-call-clingo-choice' on interactively chosen FILE."
  (interactive "f")
  (clingo-asp-call-clingo-choice (list file)))


(defun clingo-asp-call-clingo-files-choice ()
  "Call `clingo-asp-call-clingo-choice' on interactively chosen files."
  (interactive)
  (clingo-asp-call-clingo-choice (call-interactively #'clingo-asp-interactively-get-file-list)))


(defun clingo-asp-call-gringo (files args)
  "Run gringo on FILES with ARGS as a new process with it's own buffer."
  (let* ((args-files (append args (mapcar #'file-truename files)))
         (gringo-process (generate-new-buffer-name "*gringo*"))
         (gringo-buffer (get-buffer-create gringo-process)))
    (apply #'make-process
           (list :name gringo-process
                 :buffer gringo-buffer
                 :command (cons clingo-asp-gringo-executable args-files)
                 :sentinel (clingo-asp-gringo-process-exit gringo-process)))
    (pop-to-buffer gringo-buffer)))


(defun clingo-asp-call-gringo-on-current-buffer ()
  "Call `clingo-asp-call-gringo-choice' on the file opened in the current buffer."
  (interactive)
  (let ((this-file (buffer-file-name)))
    (clingo-asp-call-gringo-choice (list this-file))))


(defun clingo-asp-call-gringo-on-current-region (start end)
  "Run clingo on the region from START to END."
  (interactive "r")
  (let ((temp-file (make-temp-file "clingo-region" nil ".lp" nil)))
    (write-region start end temp-file t)
    (clingo-asp-call-gringo-choice (list temp-file))))


(defun clingo-asp-call-gringo-choice (files)
  "Call `clingo-asp-call-gringo' on FILES with chosen arguments."
  (clingo-asp-call-gringo files (clingo-asp-arguments-query)))


(defun clingo-asp-call-gringo-file-choice (file)
  "Call `clingo-asp-call-gringo-choice' on interactively chosen FILE."
  (interactive "f")
  (clingo-asp-call-gringo-choice (list file)))


(defun clingo-asp-call-gringo-files-choice ()
  "Call `clingo-asp-call-gringo-choice' on interactively chosen files."
  (interactive)
  (clingo-asp-call-gringo-choice (call-interactively #'clingo-asp-interactively-get-file-list)))

;; calling clingo end



;; font-lock
(defcustom clingo-asp-font-lock-keywords
  '((":-" . 'font-lock-punctuation-face)
    ("\\(?:not\\|-[A-Za-z0-9_']\\)" . 'font-lock-negation-char-face)
    ("0x[0-9A-Fa-f]+" . 'font-lock-number-face) ;; hexadeciamal
    ("0o[1-7]+" . 'font-lock-number-face) ;; octal
    ("0b[0-1]+" . 'font-lock-number-face) ;; binary
    ("0\\|\\(?:[1-9][0-9]*\\)" . 'font-lock-number-face) ;; deciamal
    ("[_']*[A-Z][A-Za-z0-9_']*" . 'font-lock-variable-use-face) ;; variable
    ("_*[a-z][A-Za-z0-9_']*" . 'font-lock-constant-face) ;; identifier/constant
    )
"Font definitions for `clingo-asp'."
:type '(repeat ('string 'symbol)))
;; font-lock end


;; syntax table
(defvar clingo-asp-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?. "." table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?% "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?' "w" table)
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?# "'" table)
    table))
;; syntax table end


;; keymap
(defvar clingo-asp-mode-map (make-sparse-keymap)  "Keymap for `clingo-asp-mode'.")

(define-key clingo-asp-mode-map (kbd "C-c C-c b") #'clingo-asp-call-clingo-on-current-buffer)
(define-key clingo-asp-mode-map (kbd "C-c C-c r") #'clingo-asp-call-clingo-on-current-region)
(define-key clingo-asp-mode-map (kbd "C-c C-c f") #'clingo-asp-call-clingo-file-choice)
(define-key clingo-asp-mode-map (kbd "C-c C-c F") #'clingo-asp-call-clingo-files-choice)

(define-key clingo-asp-mode-map (kbd "C-c C-g b") #'clingo-asp-call-gringo-on-current-buffer)
(define-key clingo-asp-mode-map (kbd "C-c C-g r") #'clingo-asp-call-gringo-on-current-region)
(define-key clingo-asp-mode-map (kbd "C-c C-g f") #'clingo-asp-call-gringo-file-choice)
(define-key clingo-asp-mode-map (kbd "C-c C-g F") #'clingo-asp-call-gringo-files-choice)

;; keymap end

;;; define clingo-asp-mode
;;;###autoload
(define-derived-mode clingo-asp-mode prog-mode "clingo-asp"
  (kill-all-local-variables)
  (setq-local major-mode 'clingo-asp-mode)
  (setq-local mode-name "Clingo ASP")
  (setq-local font-lock-defaults '(clingo-asp-font-lock-keywords))
  (set-syntax-table clingo-asp-syntax-table)
  (use-local-map clingo-asp-mode-map)
  (setq-local comment-start "%")
  (setq-local comment-end "")
  (setq-local tab-width clingo-asp-indentation))

(provide 'clingo-asp-mode)
;;; clingo-asp-mode.el ends here
