# SPDX-License-Identifier: PMPL-1.0-or-later
# Haskell library template with Stack

{
  metadata = {
    name = "haskell-stack-library",
    description = "Haskell library with Stack build system",
    version = "1.0.0",
    author = "Jonathan D.A. Jewell",
    license = "PMPL-1.0-or-later",
  },

  structure = {
    directories = [
      "src",
      "test",
      "app",
      ".machine_readable",
      ".github/workflows",
      "docs",
    ],

    files = {
      # Package definition
      "package.yaml" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
name: {{name}}
version: 0.1.0.0
github: "{{github_user}}/{{name}}"
license: PMPL-1.0-or-later
author: "Jonathan D.A. Jewell"
maintainer: "j.d.a.jewell@open.ac.uk"
copyright: "{{year}} Jonathan D.A. Jewell"

extra-source-files:
  - README.adoc
  - CHANGELOG.md

synopsis: {{description}}
category: {{category}}

description: |
  {{long_description}}

dependencies:
  - base >= 4.7 && < 5

ghc-options:
  - -Wall
  - -Wcompat
  - -Widentities
  - -Wincomplete-record-updates
  - -Wincomplete-uni-patterns
  - -Wmissing-export-lists
  - -Wmissing-home-modules
  - -Wpartial-fields
  - -Wredundant-constraints

library:
  source-dirs: src

executables:
  {{name}}-exe:
    main: Main.hs
    source-dirs: app
    ghc-options:
      - -threaded
      - -rtsopts
      - -with-rtsopts=-N
    dependencies:
      - {{name}}

tests:
  {{name}}-test:
    main: Spec.hs
    source-dirs: test
    ghc-options:
      - -threaded
      - -rtsopts
      - -with-rtsopts=-N
    dependencies:
      - {{name}}
      - hspec
      - QuickCheck
        '',
      },

      # Stack configuration
      "stack.yaml" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
resolver: lts-22.39

packages:
  - .

extra-deps: []
        '',
      },

      # Main library module
      "src/Lib.hs" = {
        content = ''
{- |
Module      : Lib
Description : Main library module for {{name}}
Copyright   : (c) {{year}} Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : j.d.a.jewell@open.ac.uk

Main library module providing core functionality.
-}

-- SPDX-License-Identifier: PMPL-1.0-or-later
module Lib
    ( someFunc
    , greet
    ) where

-- | Example function
someFunc :: IO ()
someFunc = putStrLn "someFunc"

-- | Greet someone by name
greet :: String -> String
greet name = "Hello, " ++ name ++ "!"
        '',
      },

      # Executable
      "app/Main.hs" = {
        content = ''
{- |
Module      : Main
Description : Executable entry point for {{name}}
Copyright   : (c) {{year}} Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : j.d.a.jewell@open.ac.uk
-}

-- SPDX-License-Identifier: PMPL-1.0-or-later
module Main (main) where

import Lib

main :: IO ()
main = do
    putStrLn "{{name}} v0.1.0"
    someFunc
        '',
      },

      # Test suite
      "test/Spec.hs" = {
        content = ''
{- |
Module      : Main
Description : Test suite for {{name}}
Copyright   : (c) {{year}} Jonathan D.A. Jewell
License     : PMPL-1.0-or-later
Maintainer  : j.d.a.jewell@open.ac.uk
-}

-- SPDX-License-Identifier: PMPL-1.0-or-later
{-# OPTIONS_GHC -F -pgmF hspec-discover #-}
        '',
      },

      "test/LibSpec.hs" = {
        content = ''
-- SPDX-License-Identifier: PMPL-1.0-or-later
module LibSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Lib

spec :: Spec
spec = do
    describe "greet" $ do
        it "greets the given name" $ do
            greet "World" `shouldBe` "Hello, World!"

        it "works with any string" $ property $
            \name -> greet name == "Hello, " ++ name ++ "!"
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
    stack setup
    stack build --only-dependencies

build:
    stack build

test:
    stack test

run *ARGS:
    stack run -- {{ARGS}}

repl:
    stack ghci

clean:
    stack clean

watch:
    stack build --file-watch

haddock:
    stack haddock --open

fmt:
    find src test app -name "*.hs" -exec fourmolu -i {} \;

lint:
    hlint src test app
        '',
      },

      # HLint configuration
      ".hlint.yaml" = {
        content = ''
# SPDX-License-Identifier: PMPL-1.0-or-later
- ignore: {name: "Redundant do"}
- ignore: {name: "Use camelCase"}
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
    (version "0.1.0.0")
    (schema-version "1.0")
    (created "{{created_date}}")
    (updated "{{created_date}}")
    (project "{{name}}")
    (repo "github.com/{{github_user}}/{{name}}"))

  (project-context
    (name "{{name}}")
    (tagline "{{description}}")
    (tech-stack ("Haskell" "Stack")))

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
      ("Implement core library functions")
      ("Add comprehensive test suite")
      ("Write Haddock documentation")))

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

[source,bash]
----
git clone https://github.com/{{github_user}}/{{name}}.git
cd {{name}}
just setup
just build
----

== Usage

[source,haskell]
----
import Lib

main :: IO ()
main = putStrLn $ greet "World"
----

== Development

[source,bash]
----
just build     # Build project
just test      # Run tests
just repl      # Start GHCi
just watch     # Auto-rebuild on changes
just haddock   # Build documentation
just fmt       # Format code
just lint      # Run HLint
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
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: haskell-actions/setup@v2
        with:
          ghc-version: '9.8'
          enable-stack: true
          stack-version: 'latest'

      - name: Cache Stack dependencies
        uses: actions/cache@v4
        with:
          path: ~/.stack
          key: ${{ runner.os }}-stack-${{ hashFiles('stack.yaml.lock') }}

      - name: Build dependencies
        run: stack build --only-dependencies

      - name: Build
        run: stack build

      - name: Run tests
        run: stack test

      - name: Generate docs
        run: stack haddock
        '',
      },
    },
  },
}
