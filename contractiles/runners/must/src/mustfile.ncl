{
  must_have = [
    { path = "LICENSE-AGPL", hash = "sha512-..." },
    { path = "README.adoc", contains = ["SPDX-License-Identifier: PMPL-1.0"] }
  ],
  must_not_have = ["Makefile", "node_modules/"],
  tasks = {
    build = {
      steps = ["just build"],
      must_have = [{ path = "bin/must", mode = "0755" }]
    },
    deploy = {
      steps = ["podman build -t must:latest ."],
      must_have = [{ path = "Containerfile" }]
    }
  }
}
