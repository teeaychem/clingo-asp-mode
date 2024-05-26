;;; clingo-ts-mode.el ---- A major mode for editing clingo files with tree-sitter. -*- lexical-binding: t -*-

;;; Commentary:

;; no commentary for the moment

;;; Code:

(defgroup clingo-ts-mode nil
  "Major mode for editing clingo files."
  :group 'languages
  :prefix "clingo-ts-")


(defcustom clingo-ts-mode-version "0.0.1"
  "Version of `clingo-ts-mode'."
  :type 'string
  :group 'clingo-ts-mode)


(defcustom clingo-ts-path (executable-find "clingo")
  "Path to clingo binary used for execution."
  :type 'string
  :group 'clingo-ts-mode)

(defcustom clingo-ts-indentation 2
  "Level of indentation."
  :type 'integer
  :group 'clingo-ts-mode)


(defvar clingo-ts-font-lock-rules
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
    ([(function)] @font-lock-function-call-face))


(setq-local treesit-font-lock-settings
            (apply #'treesit-font-lock-rules
                 clingo-ts-font-lock-rules)))


(defun clingo-ts-setup ()
  "Setup for `clingo-ts-mode'."
  (setq-local treesit-font-lock-settings (apply #'treesit-font-lock-rules clingo-ts-font-lock-rules))
  (setq-local font-lock-defaults nil)
  (setq-local treesit-font-lock-feature-list
              '((punctuation
                 variable
                 constant
                 number
                 comment
                 negation
                 operator
                 function
                 string)))
  (treesit-major-mode-setup))


;; exit code start
(defconst exit-codes
  '((128 "E_NO_RUN" "Search not started because of syntax or command line error.")
    (65 "E_ERROR" "Run was interrupted by internal error.")
    (33 "E_MEMORY" "Run was interrupted by out of memory exception.")
    (20 "E_EXHAUST" "Search-space was completely examined.")
    (10 "E_SAT" "At least one model was found.")
    (1 "E_INTERRUPT" "Run was interrupted.")
    (0 "E_UNKNOWN" "Satisfiablity of problem not known; search not started.")))


(defun decode-exit (code)
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
;; exit code end

(defun codes-to-string (codes)
  "Return a summary string of CODES."
  (let* ((code-sym (string-join (mapcar (lambda (x) (cadr (assoc x exit-codes))) codes)" + "))
         (code-exp (string-join (mapcar (lambda (x) (caddr (assoc x exit-codes))) codes) " ")))
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
            (princ (format "Process: %s exited with: %s" process (decode-exit the-code))))))))


(defun run-clingo (files args)
  "Run clingo on FILES with ARGS as a new process with it's own buffer."
  (let* ((clingo-program (executable-find "clingo"))
         (args-files (append args (mapcar #'file-truename files)))
         (clingo-process (generate-new-buffer-name "*clingo*"))
         (clingo-buffer (get-buffer-create clingo-process)))
    (with-current-buffer clingo-buffer
      (insert (format "%s" args-files))
        )
    (apply #'make-process
           (list :name clingo-process
                 :buffer clingo-buffer
                 :command (cons clingo-program args-files)
                 :sentinel (clingo-process-exit clingo-process)))
    (pop-to-buffer clingo-buffer)))


(defun run-clingo-on-current-file ()
  "Call `run-clingo-choice' on the file opened in the current buffer."
  (interactive)
  (let ((this-file (buffer-file-name)))
    (run-clingo-choice (list this-file))))


(defun run-clingo-on-current-region (start end)
  "Run clingo on the region from START to END."
  (interactive "r")
  (let ((temp-file (make-temp-file "clingo-region" nil ".lp" nil)))
    (write-region start end temp-file t)
    (run-clingo-choice (list temp-file))))


(defgroup clingo-command nil
  "Commands used by `clingo-ts-mode'."
  :group 'clingo-ts-mode)


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
     :help "--models=(prompt: n)"))
;;   "Descriptions and paired functions which generate arguments to pass to clingo.
;; Functions return a list of strings where each sting is a unique argument.
;; The third element is a description to be used by `annotate-command'"
;;   :group 'clingo-command
  )


(defun annotate-command (command)
  "Determine formatting based on COMMAND.
If COMMAND uses identity for a static list and description is given,
concatendate the list.
Otherwise, use the description given in the command-list."
  (let* ((associated-list (assoc command clingo-command-list))
        (eval-as-string (format "%s" (caadr associated-list)))
        (the-string
         (cond ((and (string-equal eval-as-string "identity") (string-equal (caddr associated-list) ""))
                (format "%s" (string-join (cdadr associated-list) " ")))
               (t (caddr associated-list)))))
    (format "  %s" the-string)))


(defun clingo-command-query ()
  "Query user for arguments to pass to clingo."
  (let* ((default "Vanilla")
         (completion-ignore-case t)
         ;; (completion-extra-properties '(:annotation-function annotate-command))
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


(defun run-clingo-choice (files)
  "Interactively select arguments.
Then, call `run-clingo' on FILES with those arguments."
  (let ((option (clingo-command-query)))
    (run-clingo files option)))


(defun run-clingo-file-choice (file)
  "Call `run-clingo-choice' on interactively chosen FILE."
  (interactive "f")
  (run-clingo-choice (list file)))


(defun interactively-get-file-list (file)
  "A list of interactively chosen FILEs.
Choosing anything other than an existing file ends choice.
E.g. if `done' is not a file choose `done' to return the list."
  (interactive "F")
  (if (file-exists-p file)
      (cons file (call-interactively #'interactively-get-file-list))
    (list )))

(defun run-clingo-files-choice ()
  (interactive)
  (let ((files (call-interactively #'interactively-get-file-list)))
    (message (format "%s" files))))


;;; define clingo-ts-mode
;;;###autoload
(define-derived-mode clingo-ts-mode prog-mode "clingo"
  (setq-local font-lock-defaults nil)
  (setq-local comment-start "%")
  (setq-local comment-end "")
  (setq-local tab-width clingo-ts-indentation)
  (when (treesit-ready-p 'clingo)
    (treesit-parser-create 'clingo)
    (clingo-ts-setup)))


(define-key clingo-ts-mode-map (kbd "C-c C-c") #'run-clingo-on-current-file)
(define-key clingo-ts-mode-map (kbd "C-c C-r") #'run-clingo-on-current-region)
(define-key clingo-ts-mode-map (kbd "C-c C-f") #'run-clingo-file-choice)
(define-key clingo-ts-mode-map (kbd "C-c C-d") #'run-clingo-files-choice)
(define-key clingo-ts-mode-map (kbd "C-c C-b") #'clingo-build-command)







(provide 'clingo-ts-mode)

;;; clingo-ts-mode.el ends here
