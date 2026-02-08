;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2025 hyperpolymath
;;
;; Guix package definition for git-hud
;; Build: guix build -f guix.scm
;; Shell: guix shell -D -f guix.scm

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system gnu)
             (guix build-system mix)
             (guix licenses)
             (gnu packages erlang)
             (gnu packages elixir)
             (gnu packages node)
             (gnu packages web)
             (gnu packages ada)
             (gnu packages base))

;; Backend (Elixir Phoenix)
(define-public git-hud-backend
  (package
    (name "git-hud-backend")
    (version "0.1.0")
    (source
     (local-file "backend" "git-hud-backend-checkout"
                 #:recursive? #t
                 #:select? (git-predicate ".")))
    (build-system mix-build-system)
    (arguments
     `(#:erlang ,erlang-26
       #:elixir ,elixir
       #:phases
       (modify-phases %standard-phases
         (add-before 'build 'set-env
           (lambda _
             (setenv "MIX_ENV" "prod"))))))
    (native-inputs
     (list elixir erlang))
    (inputs
     (list openssl))
    (synopsis "Gitvisor backend service")
    (description
     "Phoenix-based backend for Gitvisor repository intelligence platform.
Features GraphQL API, multi-database support (ArangoDB, SQLite, Dragonfly),
and OAuth integration for GitHub/GitLab.")
    (home-page "https://github.com/hyperpolymath/git-hud")
    (license expat)))

;; TUI (Ada terminal interface)
(define-public git-hud-tui
  (package
    (name "git-hud-tui")
    (version "0.1.0")
    (source
     (local-file "tui" "git-hud-tui-checkout"
                 #:recursive? #t))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda _
             (invoke "gprbuild" "-P" "git-hud_tui.gpr" "-XMODE=release")))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((bin (string-append (assoc-ref outputs "out") "/bin")))
               (mkdir-p bin)
               (install-file "bin/git-hud_tui" bin))))
         (delete 'check))))
    (native-inputs
     (list gnat gprbuild))
    (synopsis "Gitvisor terminal user interface")
    (description
     "Ada-based terminal user interface for Gitvisor.  Provides keyboard-driven
navigation and visualization of repository metrics in the terminal.")
    (home-page "https://github.com/hyperpolymath/git-hud")
    (license expat)))

;; Development package (all components)
(define-public git-hud-dev
  (package
    (name "git-hud-dev")
    (version "0.1.0")
    (source
     (local-file "." "git-hud-dev-checkout"
                 #:recursive? #t
                 #:select? (git-predicate ".")))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (delete 'build)
         (delete 'check)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (mkdir-p out)
               (copy-recursively "." out)))))))
    (native-inputs
     (list elixir
           erlang
           node-lts
           deno
           gnat
           gprbuild))
    (synopsis "Gitvisor development environment")
    (description
     "Full development environment for Gitvisor including Elixir backend,
ReScript frontend, and Ada TUI components.")
    (home-page "https://github.com/hyperpolymath/git-hud")
    (license expat)))

git-hud-backend
