;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for recon-silly-ation

(define playbook
  `((version . "1.0.0")
    (procedures
      ((build
         (("rescript" . "npx rescript build")
          ("wasm" . "cd wasm-modules && cargo build --release --target wasm32-unknown-unknown")
          ("haskell" . "cd validator && cabal build")
          ("all" . "just build")))
       (test
         (("unit" . "deno test --allow-all tests/")
          ("lint" . "deno lint src/ tests/")
          ("format" . "deno fmt src/ tests/")
          ("all" . "just test")))
       (deploy
         (("container-build" . "podman build -f Containerfile -t recon-silly-ation:latest .")
          ("container-run" . "podman run --rm -it recon-silly-ation:latest")
          ("compile-aot" . "deno compile --allow-all --output=bin/recon-silly-ation src/main.js")))
       (scan
         (("single" . "deno run --allow-all src/main.js scan --repo /path/to/repo")
          ("daemon" . "deno run --allow-all src/main.js daemon --repo /path/to/repo --interval 300")
          ("panic-attack" . "panic-attack assail . --output /tmp/recon-scan.json")
          ("echidna" . "echidna proof .")))
       (release
         (("version-bump" . "just version-bump")
          ("changelog" . "just changelog")
          ("tag" . "git tag -a v0.x.0 -m 'Release v0.x.0'")
          ("push" . "git push origin main --tags && git push gitlab main --tags")))
       (rollback
         (("container" . "podman stop recon-silly-ation && podman rm recon-silly-ation")
          ("git" . "git revert HEAD")
          ("database" . "arangosh --server.database reconciliation --javascript.execute scripts/rollback.js")))
       (debug
         (("logs" . "podman logs recon-silly-ation")
          ("arango-shell" . "arangosh --server.database reconciliation")
          ("repl" . "deno repl --allow-all")
          ("wasm-test" . "cd wasm-modules && cargo test")))))
    (alerts
      ((pipeline-failure . ((severity . "high") (action . "check logs, retry, escalate")))
       (arango-connection . ((severity . "critical") (action . "verify ArangoDB running, check credentials")))
       (wasm-load-failure . ((severity . "medium") (action . "rebuild WASM modules, check target")))))
    (contacts
      ((maintainer . "Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>")
       (security . "jonathan.jewell@open.ac.uk")
       (repository . "https://github.com/hyperpolymath/recon-silly-ation")))))
