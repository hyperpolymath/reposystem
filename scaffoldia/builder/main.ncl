# SPDX-License-Identifier: MPL-2.0
# Scaffoldia - Main builder configuration
# Composes repository scaffolds using Nickel's powerful type system

# Import merge utilities
let merge = import "./merge.ncl" in

# Template configuration schema
let TemplateConfig = {
  name | String,
  description | String | default = "",
  version | String | default = "0.1.0",
  author | String | default = "",
  license | String | default = "MPL-2.0",
  language | [| 'Rust, 'Haskell, 'ReScript, 'Nickel, 'Gleam, 'OCaml, 'Ada, 'Julia, 'Scheme, 'Bash |],
  features | Array String | default = [],
} in

# File generation schema
let FileSpec = {
  path | String,
  content | String,
  mode | [| 'Create, 'Merge, 'Skip |] | default = 'Create,
  executable | Bool | default = false,
} in

# Project structure schema
let ProjectStructure = {
  directories | Array String | default = [],
  files | Array FileSpec | default = [],
} in

# Built-in templates for each language
let rust_template = fun config => {
  directories = [
    "src",
    "src/bin",
    "tests",
    ".github/workflows",
  ],
  files = [
    {
      path = "Cargo.toml",
      content = m%"
[package]
name = "%{config.name}"
version = "%{config.version}"
edition = "2021"
authors = ["%{config.author}"]
license = "%{config.license}"
description = "%{config.description}"

[dependencies]
clap = { version = "4", features = ["derive"] }
anyhow = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"

[dev-dependencies]
assert_cmd = "2"
predicates = "3"
"%,
    },
    {
      path = "src/main.rs",
      content = m%"
// SPDX-License-Identifier: %{config.license}
//! %{config.name} - %{config.description}

use clap::Parser;
use anyhow::Result;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Input to process
    #[arg(short, long)]
    input: Option<String>,

    /// Verbose output
    #[arg(short, long, default_value_t = false)]
    verbose: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    if args.verbose {
        println!("Running %{config.name}...");
    }

    // TODO: Implement main logic

    Ok(())
}
"%,
    },
    {
      path = "README.md",
      content = m%"
# %{config.name}

%{config.description}

## Installation

```bash
cargo install --path .
```

## Usage

```bash
%{config.name} --help
```

## License

%{config.license}
"%,
    },
    {
      path = ".gitignore",
      content = m%"
/target/
Cargo.lock
*.swp
*.swo
.DS_Store
"%,
    },
  ],
} in

let haskell_template = fun config => {
  directories = [
    "src",
    "app",
    "test",
    ".github/workflows",
  ],
  files = [
    {
      path = "%{config.name}.cabal",
      content = m%"
cabal-version:      3.0
name:               %{config.name}
version:            %{config.version}
synopsis:           %{config.description}
license:            %{config.license}
author:             %{config.author}
build-type:         Simple

library
    exposed-modules:  Lib
    hs-source-dirs:   src
    default-language: Haskell2010
    build-depends:    base >= 4.14 && < 5

executable %{config.name}
    main-is:          Main.hs
    hs-source-dirs:   app
    default-language: Haskell2010
    build-depends:    base >= 4.14 && < 5, %{config.name}

test-suite %{config.name}-test
    type:             exitcode-stdio-1.0
    main-is:          Main.hs
    hs-source-dirs:   test
    default-language: Haskell2010
    build-depends:    base >= 4.14 && < 5, %{config.name}, hspec
"%,
    },
    {
      path = "src/Lib.hs",
      content = m%"
{- SPDX-License-Identifier: %{config.license} -}
module Lib (someFunc) where

someFunc :: IO ()
someFunc = putStrLn "someFunc"
"%,
    },
    {
      path = "app/Main.hs",
      content = m%"
{- SPDX-License-Identifier: %{config.license} -}
module Main where

import Lib

main :: IO ()
main = someFunc
"%,
    },
  ],
} in

let rescript_template = fun config => {
  directories = [
    "src",
    "src/bindings",
    ".github/workflows",
  ],
  files = [
    {
      path = "rescript.json",
      content = m%"
{
  "name": "%{config.name}",
  "version": "%{config.version}",
  "sources": [
    { "dir": "src", "subdirs": true }
  ],
  "package-specs": {
    "module": "es6",
    "in-source": true
  },
  "suffix": ".res.js",
  "bs-dependencies": ["@rescript/core"],
  "warnings": {
    "number": "+a-4-9-27-40-42-44-48-50-61"
  }
}
"%,
    },
    {
      path = "src/Main.res",
      content = m%"
// SPDX-License-Identifier: %{config.license}
// %{config.name} - %{config.description}

open RescriptCore

let main = () => {
  Console.log("%{config.name} running...")
}

main()
"%,
    },
    {
      path = "deno.json",
      content = m%"
{
  "tasks": {
    "build": "rescript build",
    "watch": "rescript build -w",
    "clean": "rescript clean",
    "start": "deno run --allow-read --allow-write src/Main.res.js"
  },
  "imports": {
    "@rescript/core": "npm:@rescript/core@^1"
  }
}
"%,
    },
  ],
} in

# Template selector
let get_template = fun language =>
  language
  |> match {
    'Rust => rust_template,
    'Haskell => haskell_template,
    'ReScript => rescript_template,
    _ => rust_template,  # Default fallback
  }
in

# Main build function
let build = fun config =>
  let template_fn = get_template config.language in
  let structure = template_fn config in
  merge.merge_structures structure {
    directories = [".github", ".machine_readable"],
    files = [
      {
        path = "SECURITY.md",
        content = m%"
# Security Policy

## Reporting a Vulnerability

Please report security vulnerabilities to the maintainers privately.
"%,
      },
      {
        path = "LICENSE",
        content = "See LICENSE.txt for full license text.",
      },
    ],
  }
in

# Export
{
  TemplateConfig,
  FileSpec,
  ProjectStructure,
  build,
  rust_template,
  haskell_template,
  rescript_template,
}
