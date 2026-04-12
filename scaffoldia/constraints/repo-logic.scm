;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Scaffoldia - Repository structure logic using MiniKanren
;; This module defines relational constraints for validating project structures

(use-modules (ice-9 match)
             (srfi srfi-1))

;; MiniKanren core (simplified implementation)
;; In production, use a full MiniKanren library

(define (var name) (list 'var name))
(define (var? x) (and (pair? x) (eq? (car x) 'var)))

(define empty-subst '())

(define (walk v subst)
  (cond
    ((var? v)
     (let ((binding (assoc v subst)))
       (if binding
           (walk (cdr binding) subst)
           v)))
    (else v)))

(define (unify u v subst)
  (let ((u (walk u subst))
        (v (walk v subst)))
    (cond
      ((eq? u v) subst)
      ((var? u) (cons (cons u v) subst))
      ((var? v) (cons (cons v u) subst))
      ((and (pair? u) (pair? v))
       (let ((s (unify (car u) (car v) subst)))
         (and s (unify (cdr u) (cdr v) s))))
      (else #f))))

;; Project structure relations

;; A project has a language
(define (project-language project lang)
  (lambda (subst)
    (let ((subst* (unify (list 'project-lang project) lang subst)))
      (if subst* (list subst*) '()))))

;; A language requires certain files
(define (language-requires lang files)
  (match lang
    ('rust '("Cargo.toml" "src/main.rs" "src/lib.rs"))
    ('haskell '("*.cabal" "src/" "app/"))
    ('rescript '("rescript.json" "src/" "deno.json"))
    ('nickel '("*.ncl"))
    ('gleam '("gleam.toml" "src/"))
    ('ocaml '("dune-project" "*.opam" "lib/" "bin/"))
    ('ada '("*.gpr" "src/"))
    ('julia '("Project.toml" "src/"))
    ('scheme '("*.scm"))
    (_ '())))

;; A project should have common files
(define (common-project-files)
  '("README.md" "README.adoc"    ; At least one
    "LICENSE" "LICENSE.txt"      ; At least one
    ".gitignore"
    "SECURITY.md"
    ".editorconfig"))

;; Check if a file matches a pattern
(define (file-matches? file pattern)
  (cond
    ((string-suffix? "/" pattern)
     ;; Directory pattern
     (and (string-suffix? "/" file)
          (string-prefix? (string-drop-right pattern 1) file)))
    ((string-prefix? "*" pattern)
     ;; Wildcard extension
     (string-suffix? (string-drop pattern 1) file))
    (else
     (string=? file pattern))))

;; Check project structure validity
(define (valid-project? project-path files language)
  (let* ((required (language-requires language))
         (common (common-project-files))
         (missing-required
          (filter (lambda (req)
                    (not (any (lambda (f) (file-matches? f req)) files)))
                  required))
         (has-readme (any (lambda (f)
                           (or (file-matches? f "README.md")
                               (file-matches? f "README.adoc")))
                         files))
         (has-license (any (lambda (f)
                            (or (file-matches? f "LICENSE")
                                (file-matches? f "LICENSE.txt")))
                          files)))
    (list
     (cons 'valid (and has-readme has-license (null? missing-required)))
     (cons 'missing-required missing-required)
     (cons 'has-readme has-readme)
     (cons 'has-license has-license))))

;; Infer missing files
(define (infer-missing-files project-path files language)
  (let* ((required (language-requires language))
         (missing (filter (lambda (req)
                           (not (any (lambda (f) (file-matches? f req)) files)))
                         required)))
    missing))

;; Suggest structure for new project
(define (suggest-structure language features)
  (let ((base-files (language-requires language))
        (common '("README.md" "LICENSE" ".gitignore" "SECURITY.md"))
        (ci-files (if (member 'ci features)
                      '(".github/workflows/ci.yml"
                        ".github/workflows/release.yml")
                      '()))
        (doc-files (if (member 'docs features)
                       '("docs/" "CONTRIBUTING.md" "CODE_OF_CONDUCT.md")
                       '())))
    (append base-files common ci-files doc-files)))

;; RSR (Rhodium Standard Repositories) compliance check
(define (rsr-compliant? files)
  (let ((required-for-rsr
         '("README.md" "LICENSE" "SECURITY.md" ".gitignore"
           ".editorconfig" "CONTRIBUTING.md")))
    (every (lambda (req)
             (any (lambda (f) (file-matches? f req)) files))
           required-for-rsr)))

;; Export interface for CLI integration
(define (check-project project-path)
  "Main entry point for project validation.
   Returns a list of issues found."
  (let* ((files (list-files project-path))
         (language (detect-language files))
         (result (valid-project? project-path files language)))
    result))

;; Detect language from files
(define (detect-language files)
  (cond
    ((any (lambda (f) (file-matches? f "Cargo.toml")) files) 'rust)
    ((any (lambda (f) (file-matches? f "*.cabal")) files) 'haskell)
    ((any (lambda (f) (file-matches? f "rescript.json")) files) 'rescript)
    ((any (lambda (f) (file-matches? f "gleam.toml")) files) 'gleam)
    ((any (lambda (f) (file-matches? f "dune-project")) files) 'ocaml)
    ((any (lambda (f) (file-matches? f "*.gpr")) files) 'ada)
    ((any (lambda (f) (file-matches? f "Project.toml")) files) 'julia)
    (else 'unknown)))

;; Stub for file listing (to be implemented with actual filesystem access)
(define (list-files path)
  '())  ; Placeholder

;; Run check from command line
(define (main args)
  (if (null? args)
      (display "Usage: guile repo-logic.scm <project-path>\n")
      (let* ((project-path (car args))
             (result (check-project project-path)))
        (display result)
        (newline))))
