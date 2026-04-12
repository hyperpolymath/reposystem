# SPDX-License-Identifier: PMPL-1.0-or-later
# Julia package template

{
  metadata = {
    name = "julia-package",
    description = "Julia package with standard structure",
    version = "1.0.0",
    author = "Jonathan D.A. Jewell",
    license = "PMPL-1.0-or-later",
  },

  structure = {
    directories = [
      "src",
      "test",
      "docs/src",
      ".machine_readable",
      ".github/workflows",
    ],

    files = {
      # Project.toml
      "Project.toml" = {
        content = ''
name = "{{name}}"
uuid = "{{uuid}}"
authors = ["Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>"]
version = "0.1.0"

[deps]

[compat]
julia = "1.9"

[extras]
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[targets]
test = ["Test"]
        '',
      },

      # Main module
      "src/{{module_name}}.jl" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
module {{module_name}}

export greet

"""
    greet(name::String)

Greet someone by name.

# Examples
```jldoctest
julia> greet("World")
"Hello, World!"
```
"""
function greet(name::String)
    return "Hello, $name!"
end

end # module {{module_name}}
        '',
      },

      # Test runner
      "test/runtests.jl" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
using {{module_name}}
using Test

@testset "{{module_name}}.jl" begin
    @testset "Basic functionality" begin
        @test greet("World") == "Hello, World!"
        @test greet("Julia") == "Hello, Julia!"
    end
end
        '',
      },

      # Justfile
      "justfile" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
# justfile - Task runner for {{name}}

default:
    @just --list

setup:
    julia --project=. -e 'using Pkg; Pkg.instantiate()'

test:
    julia --project=. test/runtests.jl

repl:
    julia --project=.

build-docs:
    julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
    julia --project=docs docs/make.jl

fmt:
    julia --project=. -e 'using JuliaFormatter; format("src"); format("test")'

clean:
    rm -rf Manifest.toml
        '',
      },

      # Documentation
      "docs/make.jl" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
using {{module_name}}
using Documenter

DocMeta.setdocmeta!({{module_name}}, :DocTestSetup, :(using {{module_name}}); recursive=true)

makedocs(;
    modules=[{{module_name}}],
    authors="Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>",
    sitename="{{module_name}}.jl",
    format=Documenter.HTML(;
        canonical="https://{{github_user}}.github.io/{{name}}",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/{{github_user}}/{{name}}",
    devbranch="main",
)
        '',
      },

      "docs/src/index.md" = {
        content = ''
```@meta
CurrentModule = {{module_name}}
```

# {{module_name}}

Documentation for [{{module_name}}](https://github.com/{{github_user}}/{{name}}).

```@index
```

```@autodocs
Modules = [{{module_name}}]
```
        '',
      },

      # STATE.scm
      ".machine_readable/STATE.scm" = {
        content = ''
;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for {{name}}
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "{{created_date}}")
    (updated "{{created_date}}")
    (project "{{name}}")
    (repo "github.com/{{github_user}}/{{name}}"))

  (project-context
    (name "{{name}}")
    (tagline "{{description}}")
    (tech-stack ("Julia")))

  (current-position
    (phase "initial")
    (overall-completion 0)
    (components ())
    (working-features ()))

  (integration
    (seo-score . "0")
    (health-score . "0")
    (reposystem-registered . "false")
    (gnosis-enabled . "true"))

  (route-to-mvp
    (milestones ()))

  (blockers-and-issues
    (critical)
    (high)
    (medium)
    (low))

  (critical-next-actions
    (immediate
      ("Implement core functionality")
      ("Add comprehensive tests")
      ("Write documentation")))

  (session-history ()))
        '',
      },

      # README template
      "README.template.adoc" = {
        content = ''
= (:project-context.name)

image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0]

// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: {{year}} {{author}}

*(:project-context.tagline)*

== Status

Phase: *(:current-position.phase)* | Progress: *(:current-position.overall-completion)%*

== Installation

[source,julia]
----
using Pkg
Pkg.add("{{name}}")
----

Or in development:

[source,bash]
----
git clone https://github.com/{{github_user}}/{{name}}.git
cd {{name}}
just setup
----

== Usage

[source,julia]
----
using {{module_name}}

greet("World")  # "Hello, World!"
----

== Development

[source,bash]
----
just test        # Run tests
just repl        # Start REPL
just build-docs  # Build documentation
just fmt         # Format code
----

== License

PMPL-1.0-or-later - see link:LICENSE.txt[LICENSE.txt]
        '',
      },

      # CI workflow
      ".github/workflows/ci.yml" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        julia-version: ['1.9', '1.10']

    steps:
      - uses: actions/checkout@v4

      - uses: julia-actions/setup-julia@v2
        with:
          version: ${{ matrix.julia-version }}

      - uses: julia-actions/cache@v2

      - name: Install dependencies
        run: |
          julia --project=. -e 'using Pkg; Pkg.instantiate()'

      - name: Run tests
        run: |
          julia --project=. test/runtests.jl
        '',
      },
    },
  },
}
