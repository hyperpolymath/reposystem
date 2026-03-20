;;; SPDX-License-Identifier: MPL-2.0-or-later
;;; Guix package definition for bitfuckit
;;; Usage: guix build -f guix.scm
;;; Or add channel: https://github.com/hyperpolymath/guix-channel

(define-module (bitfuckit)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages ada)
  #:use-module (gnu packages curl))

(define-public bitfuckit
  (package
    (name "bitfuckit")
    (version "0.2.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/hyperpolymath/bitfuckit")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system gnu-build-system)
    (native-inputs
     (list gnat gprbuild))
    (inputs
     (list curl))
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda _
             (invoke "gprbuild" "-P" "bitfuckit.gpr" "-j0")))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (share (string-append out "/share/bitfuckit"))
                    (man (string-append out "/share/man/man1"))
                    (bash-completion (string-append out "/share/bash-completion/completions"))
                    (zsh-completion (string-append out "/share/zsh/site-functions"))
                    (fish-completion (string-append out "/share/fish/vendor_completions.d")))
               (install-file "bin/bitfuckit" bin)
               (install-file "doc/bitfuckit.1" man)
               (install-file "completions/bitfuckit.bash" bash-completion)
               (install-file "completions/bitfuckit.zsh" zsh-completion)
               (install-file "completions/bitfuckit.fish" fish-completion)
               #t)))
         (delete 'check))))
    (synopsis "Community-built Bitbucket CLI that Atlassian never made")
    (description
     "bitfuckit is a command-line interface for Bitbucket Cloud, written in
Ada/SPARK for reliability.  It provides authentication, repository management,
pull request workflows, and GitHub mirroring capabilities.")
    (home-page "https://github.com/hyperpolymath/bitfuckit")
    (license license:agpl3+)))

bitfuckit
