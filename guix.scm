;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;;;
;;; guix.scm - GNU Guix package definition for reposystem
;;;
;;; Build: guix build -f guix.scm
;;; Shell: guix shell -f guix.scm
;;; Install: guix package -f guix.scm

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system cargo)
             (guix licenses)
             (gnu packages rust)
             (gnu packages rust-apps)
             (gnu packages crates-io)
             (gnu packages graphviz)
             (gnu packages guile)
             (gnu packages version-control))

(define-public reposystem
  (package
    (name "reposystem")
    (version "0.1.0")
    (source
     (local-file "." "reposystem-checkout"
                 #:recursive? #t
                 #:select? (git-predicate (current-source-directory))))
    (build-system cargo-build-system)
    (arguments
     `(#:cargo-inputs
       (("rust-clap" ,rust-clap-4)
        ("rust-serde" ,rust-serde-1)
        ("rust-serde-json" ,rust-serde-json-1)
        ("rust-tokio" ,rust-tokio-1)
        ("rust-ratatui" ,rust-ratatui-0.26)
        ("rust-crossterm" ,rust-crossterm-0.27)
        ("rust-petgraph" ,rust-petgraph-0.6)
        ("rust-walkdir" ,rust-walkdir-2)
        ("rust-toml" ,rust-toml-0.8)
        ("rust-anyhow" ,rust-anyhow-1))
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'install-man
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (man1 (string-append out "/share/man/man1")))
               (mkdir-p man1)
               (copy-file "doc/reposystem.1"
                          (string-append man1 "/reposystem.1"))))))))
    (native-inputs
     (list rust-cargo rust-rustc))
    (inputs
     (list graphviz
           guile-3.0
           git))
    (synopsis "Railway yard for your repository ecosystem")
    (description
     "Reposystem is a visual wiring layer for multi-repo component management
with aspect tagging and scenario comparison.  It treats your repository
ecosystem as a railway yard: repos as yards, dependencies as tracks,
and component switches as points.")
    (home-page "https://github.com/hyperpolymath/reposystem")
    (license agpl3+)))

reposystem
