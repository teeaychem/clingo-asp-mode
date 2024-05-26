;;; clingo-asp-mode.el ---- A major mode for editing clingo ASP files. -*- lexical-binding: t -*-

;;; Commentary:

;; no commentary for the moment

;;; Code:

(defgroup clingo-asp-mode nil
  "Major mode for editing clingo files."
  :group 'languages
  :prefix "clingo-asp-")

;; general defcustoms
(defcustom clingo-asp-mode-version "0.0.1"
  "Version of `clingo-asp-mode'."
  :type 'string
  :group 'clingo-asp-mode)

(defcustom clingo-asp-executable (executable-find "clingo")
  "Path to clingo binary used for execution."
  :type 'string
  :group 'clingo-asp-mode)

(defcustom clingo-asp-indentation 2
  "Level of indentation."
  :type 'integer
  :group 'clingo-asp-mode)
;; defcustoms end


(defvar clingo-asp-font-lock-rules
  '(:language clingo
    :feature variable
    ((variable) @font-lock-variable-use-face)

    :language clingo
    :feature punctuation
    ((dot) @font-lock-punctuation-face)

    :language clingo
    :feature constant
    ((identifier) @font-lock-constant-face)

    :language clingo
    :feature comment
    ((comment) @font-lock-comment-face)

    :language clingo
    :feature number
    ((number) @font-lock-number-face)

    :language clingo
    :feature negation
    ([(classical_negation) (default_negation)] @font-lock-negation-char-face)

    :language clingo
    :feature operator
    ([(comparison_predicate) (aggregatefunction)] @font-lock-builtin-face)

    :language clingo
    :feature string
    ([(string)] @font-lock-string-face)

    :language clingo
    :feature function
    ([(function)] @font-lock-function-call-face)))


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
    (codes-to-string decomposed)))


(defun codes-to-string (codes)
  "Return a summary string of CODES."
  (let* ((code-sym (string-join (mapcar (lambda (x) (cadr (assoc x clingo-asp-exit-codes))) codes)" + "))
         (code-exp (string-join (mapcar (lambda (x) (caddr (assoc x clingo-asp-exit-codes))) codes) " ")))
    (format "%s (%s)" code-sym code-exp)))


(defun clingo-process-exit (process-name)
  "Use with `set-process-sentinel' to perform actions after PROCESS-NAME exits."
  (lambda (process event)
    (let ((process-buffer (get-buffer process-name))
          (the-code (string-to-number (car (last (split-string event))))))
      (if (equal (substring event 0 27) "exited abnormally with code")
          (progn
            (with-current-buffer process-buffer
              (special-mode)
              (goto-char (point-min)))
            (princ (format "Process: %s exited with: %s" process (clingo-asp-decode-exit the-code))))))))
;; exit code end


(defgroup clingo-command nil
  "Commands used by `clingo-asp-mode'."
  :group 'clingo-asp-mode)


(defvar clingo-command-list
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
     :help "--models=(prompt: n)")))


(defcustom clingo-asp-command-help-separator "  "
  "String used to separate argument name from help.
Used when interactively choosing arguments."
  :type 'string
  :group 'clingo-asp-mode)


(defun clingo-asp-annotate-command (command)
  "Get annotation for COMMAND.
Used in `clingo-asp-arguments-query'."
  (concat clingo-asp-command-help-separator (clingo-asp-get-args-or-help clingo-command-list command)))


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




;; calling clingo

;; ;; helpers
(defun clingo-asp-arguments-query ()
  "Query user for arguments to pass to clingo."
  (let* ((default "Vanilla")
         (completion-ignore-case t)
         (completion-extra-properties '(:annotation-function clingo-asp-annotate-command))
         (command-plist-list (mapcar (lambda (x) (cons (plist-get x ':name) x)) clingo-command-list))
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

(defun interactively-get-file-list (file)
  "A list of interactively chosen FILEs.
Choosing anything other than an existing file ends choice.
E.g. if `done' is not a file choose `done' to return the list."
  (interactive "F")
  (if (file-exists-p file)
      (cons file (call-interactively #'interactively-get-file-list))
    (list )))
;; ;; helpers end


(defun clingo-asp-call-clingo (files args)
  "Run clingo on FILES with ARGS as a new process with it's own buffer."
  (let* ((args-files (append args (mapcar #'file-truename files)))
         (clingo-process (generate-new-buffer-name "*clingo*"))
         (clingo-buffer (get-buffer-create clingo-process)))
    (with-current-buffer clingo-buffer
      (insert (format "%s" args-files))
        )
    (apply #'make-process
           (list :name clingo-process
                 :buffer clingo-buffer
                 :command (cons clingo-asp-executable args-files)
                 :sentinel (clingo-process-exit clingo-process)))
    (pop-to-buffer clingo-buffer)))


(defun clingo-asp-call-clingo-on-current-file ()
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
  (clingo-asp-call-clingo-choice (call-interactively #'interactively-get-file-list)))
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
"Font definitions for `clingo-asp-mode'."
:type '(repeat ('string 'symbol))
)
;; font-lock end


;; syntax table
(defvar clingo-asp-table
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


;;; define clingo-asp-mode
;;;###autoload
(define-derived-mode clingo-asp-mode prog-mode "clingo-asp"
  (kill-all-local-variables)
  (setq major-mode 'clingo-asp-mode)
  (setq mode-name "Clingo ASP")
  (setq font-lock-defaults '(clingo-asp-font-lock-keywords))
  (set-syntax-table clingo-asp-table)
  (setq-local tab-width clingo-asp-indentation))


(define-key clingo-asp-mode-map (kbd "C-c C-c") #'clingo-asp-call-clingo-on-current-file)
(define-key clingo-asp-mode-map (kbd "C-c C-r") #'clingo-asp-call-clingo-on-current-region)
(define-key clingo-asp-mode-map (kbd "C-c C-f") #'clingo-asp-call-clingo-file-choice)
(define-key clingo-asp-mode-map (kbd "C-c C-F") #'clingo-asp-call-clingo-files-choice)

(provide 'clingo-asp-mode)
;;; clingo-asp-mode.el ends here
