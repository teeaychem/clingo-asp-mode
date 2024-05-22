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

;; TODO: Natural language translation of exit codes from here:
;; https://github.com/potassco/clasp/issues/42#issuecomment-459981038%3E
;; (defun decode-exit (_process-status exit-status msg)
;;   (concat "----" msg exit-status))


(defun clingo-process-exit (process-name)
  "Use with `set-process-sentinel' to perform actions after PROCESS-NAME exits."
  (lambda (process event)
    (let ((process-buffer (get-buffer process-name)))
      (with-current-buffer process-buffer
        (insert "\n")
        (insert "cheeky")
        (special-mode)
        (goto-char (point-min)))
      ;; (pop-to-buffer process-buffer)
      (princ (format "Process: %s %s" process event)))))


(defun run-clingo (file args)
  "Run clingo on FILE with ARGS."
  ;; (when (get-buffer "*clingo output*") (kill-buffer "*clingo output*"))
  (let* ((clingo-program (executable-find "clingo"))
         (args-file (nconc args (list (file-truename file))))
         ;; (clingo-buffer (get-buffer-create "*clingo output*")) ;; todo: make a toggle
         (clingo-process (generate-new-buffer-name "*clingo*"))
         (clingo-buffer (get-buffer-create clingo-process))
         (all-args (cons clingo-process (cons clingo-buffer (cons clingo-program args-file)))))
    (apply #'start-process all-args)
    (set-process-sentinel (get-process clingo-process) (clingo-process-exit clingo-process))
    (pop-to-buffer clingo-buffer)))


(defun run-clingo-on-current-file ()
  "Call `run-clingo-choice' on the file opened in the current buffer."
  (interactive)
  (let ((this-file (buffer-file-name)))
    (run-clingo-choice this-file)))


(defun run-clingo-on-current-region (start end)
  "Run clingo on the region from START to END."
  (interactive "r")
  (let ((temp-file (make-temp-file "clingo-region" nil ".lp" nil)))
    (write-region start end temp-file t)
    (run-clingo-choice temp-file)))


(defgroup clingo-command nil
  "Commands used by `clingo-ts-mode'."
  :group 'clingo-ts-mode)


(defcustom clingo-command-list
  '(("Vanilla" ())
    ("All models" ("--models=0"))
    ("All subset minimal models" ("--models=0" "--enum-mode=domRec" "--heuristic=Domain" "--dom-mod=5,16")))
  "A list of descriptions and corresponding arguments to pass to clingo."
  :group 'clingo-command
  :type '(repeat (group (string :tag "Name") (string :tag "Command"))))


(defun clingo-command-query ()
  "Query user for arguments to pass to clingo."
  (let* ((default "clingo")
         (completion-ignore-case t)
         (answer (completing-read
                  (concat "Command (default " default "): ")
                  clingo-command-list nil t
                  nil nil default)))
    (if (and answer
             (not (string-equal answer "")))
        (car-safe (cdr-safe (assoc-string answer clingo-command-list)))
      (car-safe (cdr-safe (assoc-string default clingo-command-list))))))


(defun run-clingo-choice (file)
  "Interactively select arguments.
Then, call `run-clingo' on FILE with those arguments."
  (let ((option (clingo-command-query)))
    (run-clingo file option)))


(defun run-clingo-file-choice (file)
  "Call `run-clingo-choice' on interactively chosen FILE."
  (interactive "f")
  (run-clingo-choice file))


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


(provide 'clingo-ts-mode)

;;; clingo-ts-mode.el ends here
