# This is…

An emacs major mode called `clingo-asp-mode` for editing potassco-style ASP files.

There are two main features of the mode:

1. Syntax highlighting
2. A variety of ways to call clingo (or gringo) from within emacs (and view the result in a buffer)
   - The default call command allows interactively selecting named argument collections (e.g. `all subset minimal models` will call clingo with arguments `--models=0 --enum-mode=domRec --heuristic=Domain --dom-mod=5,16`)
   - Calls can be made on the current file, region, or by interactively selecting multiple files.

In addition to `clingo-asp-mode` there is a derived mode which uses a work-in-progress treesitter grammar called `clingo-asp-ts-mode`.

# Use

``` emacs-lisp
(use-package clingo-asp-mode
  :mode "\\.lp\\'"
  :vc (:fetcher github :repo teeaychem/clingo-asp-mode))
```

## treesitter

Install `tree-sitter-clingo`: https://github.com/teeaychem/tree-sitter-clingo together with tree-sitter grammars for lua and python, and then…

``` emacs-lisp
(use-package clingo-asp-ts-mode
  :mode "\\.lp\\'"
  :vc (:fetcher github :repo teeaychem/clingo-asp-mode))
```

# Notes

built with the help of Mickey Ptersen's guide to writing a tree-sitter major mode https://www.masteringemacs.org/article/lets-write-a-treesitter-major-mode

parts inspired by pasp-mode https://github.com/santifa/pasp-mode
