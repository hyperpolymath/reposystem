# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Rhodibot.Checker do
  @moduledoc """
  RSR compliance checker.
  """

  @categories [
    :foundational_infrastructure,
    :documentation_standards,
    :security_architecture,
    :architecture_principles,
    :web_standards,
    :semantic_web,
    :foss_licensing,
    :cognitive_ergonomics,
    :lifecycle_management,
    :community_governance,
    :accountability
  ]

  @doc """
  Run all compliance checks on a repository.
  """
  def run(path, opts \\ []) do
    config = load_config(path)
    skip = Keyword.get(opts, :skip, config[:skip] || [])

    results =
      @categories
      |> Enum.reject(fn cat -> cat in skip end)
      |> Enum.map(fn category ->
        {category, check_category(category, path)}
      end)

    total_checks = Enum.sum(Enum.map(results, fn {_, r} -> length(r.checks) end))
    passed_checks = Enum.sum(Enum.map(results, fn {_, r} -> Enum.count(r.checks, & &1.passed) end))

    score = if total_checks > 0, do: round(passed_checks / total_checks * 100), else: 0

    {:ok,
     %{
       path: path,
       score: score,
       level: Rhodibot.level(score),
       total_checks: total_checks,
       passed_checks: passed_checks,
       categories: Map.new(results),
       timestamp: DateTime.utc_now()
     }}
  end

  defp load_config(path) do
    config_path = Path.join(path, ".rhodibot.toml")

    if File.exists?(config_path) do
      case Toml.decode_file(config_path) do
        {:ok, config} -> config
        _ -> %{}
      end
    else
      %{}
    end
  end

  # Category checks

  defp check_category(:foundational_infrastructure, path) do
    %{
      name: "Foundational Infrastructure",
      checks: [
        check_file(path, "flake.nix", "Nix flake"),
        check_file(path, "justfile", "Justfile"),
        check_any(path, [".gitlab-ci.yml", ".github/workflows"], "CI/CD config"),
        check_any(path, ["Containerfile", "Dockerfile"], "Container config")
      ]
    }
  end

  defp check_category(:documentation_standards, path) do
    %{
      name: "Documentation Standards",
      checks: [
        check_any(path, ["README.adoc", "README.md"], "README"),
        check_any(path, ["LICENSE.txt", "LICENSE", "LICENSE.md"], "LICENSE"),
        check_any(path, ["CODE_OF_CONDUCT.adoc", "CODE_OF_CONDUCT.md"], "Code of Conduct"),
        check_any(path, ["CONTRIBUTING.adoc", "CONTRIBUTING.md"], "Contributing guide")
      ]
    }
  end

  defp check_category(:security_architecture, path) do
    %{
      name: "Security Architecture",
      checks: [
        check_any(path, ["SECURITY.md", "SECURITY.adoc"], "Security policy"),
        check_spdx_headers(path)
      ]
    }
  end

  defp check_category(:architecture_principles, path) do
    %{
      name: "Architecture Principles",
      checks: [
        # These are harder to check automatically
        %{name: "Architecture documented", passed: check_docs_mention(path, "architecture"), file: nil}
      ]
    }
  end

  defp check_category(:web_standards, path) do
    %{
      name: "Web Standards",
      checks: [
        check_dir(path, ".well-known", ".well-known directory"),
        check_file(path, ".well-known/security.txt", "security.txt")
      ]
    }
  end

  defp check_category(:semantic_web, path) do
    %{
      name: "Semantic Web & IndieWeb",
      checks: [
        # Optional, check for schema.org in HTML files
        %{name: "Semantic markup", passed: true, file: nil, note: "Optional"}
      ]
    }
  end

  defp check_category(:foss_licensing, path) do
    %{
      name: "FOSS & Licensing",
      checks: [
        check_any(path, ["LICENSE.txt", "LICENSE"], "License file"),
        check_spdx_in_license(path)
      ]
    }
  end

  defp check_category(:cognitive_ergonomics, path) do
    %{
      name: "Cognitive Ergonomics",
      checks: [
        %{name: "Accessibility consideration", passed: true, file: nil, note: "Manual review"}
      ]
    }
  end

  defp check_category(:lifecycle_management, path) do
    %{
      name: "Lifecycle Management",
      checks: [
        check_any(path, ["CHANGELOG.md", "CHANGELOG.adoc", "CHANGES.md"], "Changelog"),
        check_semver_tags(path)
      ]
    }
  end

  defp check_category(:community_governance, path) do
    %{
      name: "Community & Governance",
      checks: [
        check_any(path, ["GOVERNANCE.adoc", "GOVERNANCE.md"], "Governance"),
        check_file(path, ".github/FUNDING.yml", "Funding info")
      ]
    }
  end

  defp check_category(:accountability, path) do
    %{
      name: "Accountability",
      checks: [
        %{name: "Audit trail capability", passed: true, file: nil, note: "Git history"}
      ]
    }
  end

  # Check helpers

  defp check_file(path, file, name) do
    full_path = Path.join(path, file)
    %{name: name, passed: File.exists?(full_path), file: file}
  end

  defp check_dir(path, dir, name) do
    full_path = Path.join(path, dir)
    %{name: name, passed: File.dir?(full_path), file: dir}
  end

  defp check_any(path, files, name) do
    found = Enum.find(files, fn f -> File.exists?(Path.join(path, f)) end)
    %{name: name, passed: found != nil, file: found}
  end

  defp check_spdx_headers(path) do
    # Check if source files have SPDX headers
    source_files =
      Path.wildcard(Path.join(path, "**/*.{ex,exs,res,adb,ads,jl}"))
      |> Enum.take(10)  # Sample

    has_spdx =
      source_files
      |> Enum.all?(fn file ->
        case File.read(file) do
          {:ok, content} -> String.contains?(content, "SPDX-License-Identifier")
          _ -> false
        end
      end)

    %{name: "SPDX headers in source", passed: has_spdx || Enum.empty?(source_files), file: nil}
  end

  defp check_spdx_in_license(path) do
    license_files = ["LICENSE.txt", "LICENSE", "LICENSE.md"]

    has_spdx =
      license_files
      |> Enum.any?(fn file ->
        full_path = Path.join(path, file)

        case File.read(full_path) do
          {:ok, content} -> String.contains?(content, "SPDX-License-Identifier")
          _ -> false
        end
      end)

    %{name: "SPDX in license", passed: has_spdx, file: nil}
  end

  defp check_docs_mention(path, term) do
    doc_files = ["README.adoc", "README.md", "docs/ARCHITECTURE.adoc"]

    Enum.any?(doc_files, fn file ->
      full_path = Path.join(path, file)

      case File.read(full_path) do
        {:ok, content} -> String.contains?(String.downcase(content), term)
        _ -> false
      end
    end)
  end

  defp check_semver_tags(path) do
    case System.cmd("git", ["tag", "-l"], cd: path, stderr_to_stdout: true) do
      {output, 0} ->
        tags = String.split(output, "\n", trim: true)
        has_semver = Enum.any?(tags, fn t -> Regex.match?(~r/^v?\d+\.\d+\.\d+/, t) end)
        %{name: "Semantic version tags", passed: has_semver || Enum.empty?(tags), file: nil}

      _ ->
        %{name: "Semantic version tags", passed: true, file: nil, note: "Not a git repo"}
    end
  end
end
