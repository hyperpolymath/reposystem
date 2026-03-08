{
  must_have = [
    { path = "LICENSE-AGPL", hash = "sha512-..." },
    { path = "README.adoc", contains = ["SPDX-License-Identifier: PMPL-1.0"] },
    { path = "Cargo.toml" },
    { path = "target/debug/must", mode = "0755", hash = "shake256-..." }
  ],
  must_not_have = ["Makefile", "node_modules/", "*.rs.bk"],
  tasks = {
    build = {
      steps = ["cargo build"],
      must_have = [{ path = "target/debug/must", hash = "shake256-..." }]
    },
    test = {
      steps = ["cargo test"],
      must_have = []
    },
    deploy = {
      steps = ["podman build -t must:latest ."],
      must_have = [{ path = "Containerfile" }]
    }
  },
  artifacts = {
    "must:latest": { hash_alg = "shake256", hash = "..." }
  }
}
