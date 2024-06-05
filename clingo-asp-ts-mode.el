;;; clingo-asp-ts-mode.el ---- A major mode for editing clingo ASP files with tree-sitter. -*- lexical-binding: t -*-

;;; Commentary:

;; An extension of clingo-asp-mode which makes use of tree-sitter functionality.

;;; Code:

(require 'clingo-asp-mode)

(defgroup clingo-asp-ts-mode nil
  "Major mode for editing clingo files."
  :group 'languages
  :prefix "clingo-asp-ts-")

(defcustom clingo-asp-ts-mode-version "0.0.1"
  "Version of `clingo-asp-ts-mode'."
  :type 'string
  :group 'clingo-asp-ts-mode)


(defvar clingo-asp-ts-font-lock-rules
  '(:language clingo
    :feature variable
    ((variable) @font-lock-variable-use-face)

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
    ([(comparison_predicate) (aggregate_function)] @font-lock-builtin-face)

    :language clingo
    :feature string
    ([(string)] @font-lock-string-face)

    :language clingo
    :feature function
    ([(function)] @font-lock-function-call-face)))

(defun clingo-asp-ts-setup ()
  "Setup for `clingo-asp-ts-mode'."

  (setq-local treesit-range-settings
              (treesit-range-rules
               :embed 'python
               :host 'clingo
               '((python (script_contents) @capture))

               :embed 'lua
               :host 'clingo
               '((lua (script_contents) @capture))))

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

    (setq-local treesit-font-lock-settings
                (apply #'treesit-font-lock-rules clingo-asp-ts-font-lock-rules))

  (treesit-major-mode-setup))


;;; define clingo-asp-ts-mode
;;;###autoload
(define-derived-mode clingo-asp-ts-mode clingo-asp-mode "clingo-asp-ts"
  (setq-local major-mode 'clingo-asp-ts-mode)
  (setq-local mode-name "Clingo ASP")
  (setq-local font-lock-defaults nil)
  (when (treesit-ready-p 'clingo)
    (treesit-parser-create 'clingo)
    (clingo-asp-ts-setup)))


(provide 'clingo-asp-ts-mode)

;;; clingo-asp-ts-mode.el ends here
