# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.Fixer do
  @moduledoc """
  Generate missing RSR files from templates.
  """

  @templates %{
    "README.adoc" => :readme,
    "LICENSE.txt" => :license,
    "SECURITY.md" => :security,
    "CODE_OF_CONDUCT.adoc" => :code_of_conduct,
    "CONTRIBUTING.adoc" => :contributing,
    "GOVERNANCE.adoc" => :governance,
    ".github/FUNDING.yml" => :funding,
    "flake.nix" => :flake,
    "justfile" => :justfile,
    ".well-known/security.txt" => :security_txt
  }

  @doc """
  Fix missing files in a repository.
  """
  def run(path, opts \\ []) do
    {:ok, report} = Rhodibot.check(path, opts)
    auto = Keyword.get(opts, :auto, false)
    only = Keyword.get(opts, :only)

    missing =
      report.categories
      |> Enum.flat_map(fn {_cat, data} -> data.checks end)
      |> Enum.filter(fn check -> not check.passed and check.file != nil end)
      |> Enum.map(& &1.file)

    # Filter by --only if specified
    missing =
      if only do
        only_list = String.split(only, ",") |> Enum.map(&String.trim/1)
        Enum.filter(missing, fn f -> Enum.any?(only_list, &String.contains?(f, &1)) end)
      else
        missing
      end

    if Enum.empty?(missing) do
      {:ok, %{fixed: [], skipped: [], message: "All required files present"}}
    else
      if auto do
        fixed = Enum.map(missing, fn file -> fix_file(path, file, opts) end)
        {:ok, %{fixed: fixed, skipped: []}}
      else
        {:ok, %{fixed: [], skipped: missing, message: "Run with --auto to generate files"}}
      end
    end
  end

  defp fix_file(path, file, opts) do
    template_key = Map.get(@templates, file)

    if template_key do
      content = render_template(template_key, opts)
      full_path = Path.join(path, file)

      # Ensure directory exists
      full_path |> Path.dirname() |> File.mkdir_p!()

      File.write!(full_path, content)
      %{file: file, status: :created}
    else
      %{file: file, status: :no_template}
    end
  end

  defp render_template(:readme, opts) do
    name = Keyword.get(opts, :name, "Project")

    """
    = #{name}
    :toc:

    == Overview

    [TODO: Add project description]

    == Installation

    [TODO: Add installation instructions]

    == Usage

    [TODO: Add usage examples]

    == License

    MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8
    """
  end

  defp render_template(:license, _opts) do
    """
    SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

    This project is available under your choice of:
    1. MIT License
    2. GNU Affero General Public License v3.0 or later

    See individual license texts for full terms.
    """
  end

  defp render_template(:security, _opts) do
    """
    # Security Policy

    ## Reporting a Vulnerability

    Please report security vulnerabilities responsibly.

    1. Do NOT create public issues for security vulnerabilities
    2. Email the maintainers directly
    3. Include steps to reproduce

    ## Supported Versions

    | Version | Supported |
    | ------- | --------- |
    | latest  | Yes       |
    """
  end

  defp render_template(:code_of_conduct, _opts) do
    """
    = Code of Conduct

    == Our Pledge

    We pledge to make participation in our community a harassment-free experience.

    == Standards

    * Be respectful and inclusive
    * Accept constructive criticism gracefully
    * Focus on what is best for the community

    == Enforcement

    Violations may be reported to the maintainers.
    """
  end

  defp render_template(:contributing, _opts) do
    """
    = Contributing

    Thank you for your interest in contributing!

    == How to Contribute

    1. Fork the repository
    2. Create a feature branch
    3. Make your changes
    4. Submit a pull request

    == Code Style

    Please follow the existing code style.
    """
  end

  defp render_template(:governance, _opts) do
    """
    = Governance

    == Decision Making

    This project uses lazy consensus for most decisions.

    == Roles

    * Maintainers: Full commit access
    * Contributors: Submit PRs and issues
    """
  end

  defp render_template(:funding, _opts) do
    """
    # Funding information
    github: []
    custom: []
    """
  end

  defp render_template(:flake, _opts) do
    """
    {
      description = "Project";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      outputs = { self, nixpkgs }: {
        devShells.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
          buildInputs = [];
        };
      };
    }
    """
  end

  defp render_template(:justfile, _opts) do
    """
    # Task runner

    default:
        @just --list

    test:
        echo "No tests configured"

    build:
        echo "No build configured"
    """
  end

  defp render_template(:security_txt, _opts) do
    """
    Contact: [TODO: Add contact]
    Expires: #{Date.add(Date.utc_today(), 365) |> Date.to_iso8601()}T00:00:00.000Z
    Preferred-Languages: en
    """
  end
end
