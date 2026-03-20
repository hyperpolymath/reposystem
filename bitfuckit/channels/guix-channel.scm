;;; SPDX-License-Identifier: MPL-2.0-or-later
;;; Guix channel definition for hyperpolymath packages
;;; Add to ~/.config/guix/channels.scm:
;;;
;;; (cons*
;;;   (channel
;;;     (name 'hyperpolymath)
;;;     (url "https://github.com/hyperpolymath/guix-channel")
;;;     (branch "main"))
;;;   %default-channels)

(define-module (hyperpolymath packages bitfuckit)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages ada)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages tls))

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
     (list curl openssl))
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'build
            (lambda _
              (invoke "gprbuild" "-P" "bitfuckit.gpr" "-j0")))
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin"))
                    (share (string-append #$output "/share/bitfuckit"))
                    (man1 (string-append #$output "/share/man/man1")))
                (install-file "bin/bitfuckit" bin)
                (when (file-exists? "doc/bitfuckit.1")
                  (install-file "doc/bitfuckit.1" man1))))))))
    (synopsis "Bitbucket CLI for the community")
    (description
     "bitfuckit provides a command-line interface for Bitbucket Cloud,
featuring authentication, repository management, pull requests, and
mirroring.  Built with Ada/SPARK for reliability and formal verification.")
    (home-page "https://github.com/hyperpolymath/bitfuckit")
    (license license:agpl3+)))
