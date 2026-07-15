# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# megasweep — parallel estate-wide repo sweep runner (reposystem#137).
#
# Elixir-only (no Python/npm). Pure git/gh over LOCAL clones (no API rate limits).
# Owned-compute friendly: run from host cron or bag-of-actions, never metered Actions.
#
# Design: pluggable DETECTORS. A detector is a module implementing
#   name/0          -> string
#   detect/2        -> map      (per-repo, called in parallel; MUST be read-only)
#   summarize/1     -> map      (fold over all per-repo results)
# Detectors: nix-guix (reposystem#138/#139), templates (health-file presence +
# local-template drift vs the org .github canon), settings (gh-backed repo
# settings drift vs estate policy — reposystem#141). Add more by dropping a
# module in @detectors. APPLY mode is intentionally NOT implemented yet:
# megasweep is an audit/report-only canary first (mutation lands later, owner-gated).
#
# Usage:
#   elixir megasweep.exs [--detector nix-guix|templates|settings]
#                        [--root ~/developer/repos]
#                        [--jobs N] [--out report.json] [--mode audit]

defmodule Megasweep.Git do
  @moduledoc "Thin, failure-tolerant git helpers over a repo working dir."

  def repo?(path), do: File.dir?(Path.join(path, ".git"))

  def tracked_files(path) do
    case System.cmd("git", ["-C", path, "ls-files"], stderr_to_stdout: true) do
      {out, 0} -> String.split(out, "\n", trim: true)
      _ -> []
    end
  end

  def read(path, rel) do
    full = Path.join(path, rel)
    case File.read(full) do
      {:ok, body} -> body
      _ -> ""
    end
  end
end

defmodule Megasweep.Detectors.NixGuix do
  @moduledoc "Classify Nix presence vs Guix coverage + Guix-quality, per repo."

  @nix_re ~r{(^|/)(flake\.nix|flake\.lock|shell\.nix|default\.nix|\.nix-channel)$|\.nix$}
  @guix_re ~r{(^|/)(guix\.scm|\.guix-channel|manifest\.scm|channels\.scm)$}
  @ci_re ~r{\.github/workflows/.*\.ya?ml$|(^|/)\.gitlab-ci\.yml$}
  @envrc_nix_re ~r{use[ _]flake|use nix|nix-shell|nixpkgs}i
  @ci_nix_re ~r{nix-installer|determinate|nix build|nix-shell|nix develop|cachix|install-nix|uses: .*nix}i
  # invalid Guix package name: contains a space or a capital inside the quotes, or a {{placeholder}}
  @bad_name_re ~r/\(name "([^"]* [^"]*|[^"]*[A-Z][^"]*|[^"]*\{\{[^"]*)"/

  def name, do: "nix-guix"

  def detect(repo, _opts) do
    files = Megasweep.Git.tracked_files(repo)
    nix = Enum.filter(files, &Regex.match?(@nix_re, &1))
    guix = Enum.filter(files, &Regex.match?(@guix_re, &1))

    envrc_nix =
      files
      |> Enum.filter(&String.ends_with?(&1, ".envrc"))
      |> Enum.any?(fn f -> Regex.match?(@envrc_nix_re, Megasweep.Git.read(repo, f)) end)

    ci_nix_files =
      files
      |> Enum.filter(&Regex.match?(@ci_re, &1))
      |> Enum.filter(fn f -> Regex.match?(@ci_nix_re, Megasweep.Git.read(repo, f)) end)

    guix_broken =
      guix
      |> Enum.filter(&String.ends_with?(&1, "guix.scm"))
      |> Enum.filter(fn f -> Regex.match?(@bad_name_re, Megasweep.Git.read(repo, f)) end)

    verdict =
      cond do
        nix != [] and guix == [] -> "NIX_NO_GUIX"
        nix != [] and guix != [] -> "BOTH"
        nix == [] and guix != [] -> "GUIX_ONLY"
        true -> "NEITHER"
      end

    %{
      repo: Path.basename(repo),
      verdict: verdict,
      nix_files: length(nix),
      guix_files: length(guix),
      envrc_nix: envrc_nix,
      ci_nix_files: length(ci_nix_files),
      guix_broken: length(guix_broken),
      detail: %{nix: nix, ci_nix: ci_nix_files, guix_broken: guix_broken}
    }
  end

  def summarize(results) do
    relevant =
      Enum.filter(results, fn r ->
        r.nix_files > 0 or r.guix_files > 0 or r.envrc_nix or r.ci_nix_files > 0
      end)

    by_verdict = Enum.frequencies_by(relevant, & &1.verdict)

    %{
      repos_scanned: length(results),
      repos_with_surface: length(relevant),
      by_verdict: by_verdict,
      repos_with_nix: Enum.count(relevant, &(&1.nix_files > 0)),
      total_nix_files: Enum.sum(Enum.map(relevant, & &1.nix_files)),
      repos_envrc_nix: Enum.count(relevant, & &1.envrc_nix),
      repos_ci_nix: Enum.count(relevant, &(&1.ci_nix_files > 0)),
      repos_with_guix: Enum.count(relevant, &(&1.guix_files > 0)),
      guix_broken_files: Enum.sum(Enum.map(relevant, & &1.guix_broken)),
      nix_no_guix: relevant |> Enum.filter(&(&1.verdict == "NIX_NO_GUIX")) |> Enum.map(& &1.repo)
    }
  end
end

defmodule Megasweep.Detectors.Templates do
  @moduledoc """
  Health-file presence + local-template drift, per repo.

  Estate canon (reposystem#164/#167): issue/discussion/PR templates are
  inherited from the org-level .github repo — a repo carrying its own is drift.
  Health files (LICENSE/README/SECURITY/CONTRIBUTING/CODE_OF_CONDUCT) must be
  present locally.
  """

  @health %{
    "LICENSE" => ~r{^(LICENSE|LICENCE|COPYING)(\.|s/|$)}i,
    "README" => ~r{^README(\.|$)}i,
    "SECURITY" => ~r{^(\.github/)?SECURITY\.(md|adoc)$}i,
    "CONTRIBUTING" => ~r{^(\.github/|docs/)?CONTRIBUTING\.(md|adoc)$}i,
    "CODE_OF_CONDUCT" => ~r{^(\.github/|docs/)?CODE_OF_CONDUCT\.(md|adoc)$}i
  }
  @local_tpl_re ~r{^\.github/(ISSUE_TEMPLATE/|DISCUSSION_TEMPLATE/|PULL_REQUEST_TEMPLATE)}

  def name, do: "templates"

  def detect(repo, _opts) do
    files = Megasweep.Git.tracked_files(repo)
    missing = for {k, re} <- @health, not Enum.any?(files, &Regex.match?(re, &1)), do: k
    local_tpl = Enum.filter(files, &Regex.match?(@local_tpl_re, &1))

    verdict =
      cond do
        missing == [] and local_tpl == [] -> "OK"
        missing != [] and local_tpl != [] -> "BOTH_DRIFT"
        local_tpl != [] -> "LOCAL_TEMPLATES"
        true -> "MISSING_HEALTH"
      end

    %{
      repo: Path.basename(repo),
      verdict: verdict,
      missing: Enum.sort(missing),
      local_templates: length(local_tpl),
      detail: %{local_templates: local_tpl}
    }
  end

  def summarize(results) do
    %{
      repos_scanned: length(results),
      by_verdict: Enum.frequencies_by(results, & &1.verdict),
      missing_counts: results |> Enum.flat_map(& &1.missing) |> Enum.frequencies(),
      repos_local_templates: Enum.count(results, &(&1.local_templates > 0)),
      drift_repos: results |> Enum.reject(&(&1.verdict == "OK")) |> Enum.map(& &1.repo) |> Enum.sort()
    }
  end
end

defmodule Megasweep.Detectors.Settings do
  @moduledoc """
  GitHub repo-settings drift vs estate policy (reposystem#141). gh-backed,
  read-only (one `gh api repos/<slug>` GET per repo). Policy: squash/rebase
  only (never merge-commit), auto-merge on, delete-branch-on-merge on.
  """

  def name, do: "settings"

  # gh api calls hit secondary rate limits if hammered — cap concurrency.
  def max_jobs, do: 8

  def detect(repo, _opts) do
    base = %{repo: Path.basename(repo), flags: []}

    case slug(repo) do
      nil ->
        Map.put(base, :verdict, "NO_GITHUB_REMOTE")

      slug ->
        case gh_repo(slug) do
          {:ok, s} ->
            flags =
              [
                {s["allow_merge_commit"] == true, "MERGE_COMMIT_ENABLED"},
                {s["allow_auto_merge"] != true, "AUTO_MERGE_OFF"},
                {s["allow_squash_merge"] != true, "SQUASH_DISABLED"},
                {s["delete_branch_on_merge"] != true, "KEEP_STALE_BRANCHES"}
              ]
              |> Enum.filter(&elem(&1, 0))
              |> Enum.map(&elem(&1, 1))

            verdict =
              cond do
                s["archived"] -> "ARCHIVED"
                flags == [] -> "OK"
                true -> "DRIFT"
              end

            %{base | flags: flags}
            |> Map.merge(%{verdict: verdict, slug: slug, default_branch: s["default_branch"]})

          :error ->
            base |> Map.merge(%{verdict: "GH_ERROR", slug: slug})
        end
    end
  end

  defp slug(repo) do
    case System.cmd("git", ["-C", repo, "remote", "get-url", "origin"], stderr_to_stdout: true) do
      {url, 0} ->
        case Regex.run(~r{github\.com[:/]([^/\s]+/[^/\s]+?)(\.git)?$}, String.trim(url)) do
          [_, slug | _] -> slug
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp gh_repo(slug) do
    case System.cmd("gh", ["api", "repos/#{slug}"], stderr_to_stdout: true) do
      {out, 0} -> {:ok, JSON.decode!(out)}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  def summarize(results) do
    on_github = Enum.reject(results, &(&1.verdict in ["NO_GITHUB_REMOTE", "GH_ERROR"]))

    %{
      repos_scanned: length(results),
      repos_on_github: length(on_github),
      gh_errors: Enum.count(results, &(&1.verdict == "GH_ERROR")),
      by_verdict: Enum.frequencies_by(results, & &1.verdict),
      flag_counts: on_github |> Enum.flat_map(& &1.flags) |> Enum.frequencies(),
      drift_repos: on_github |> Enum.filter(&(&1.verdict == "DRIFT")) |> Enum.map(& &1.repo) |> Enum.sort()
    }
  end
end

defmodule Megasweep do
  @detectors %{
    "nix-guix" => Megasweep.Detectors.NixGuix,
    "templates" => Megasweep.Detectors.Templates,
    "settings" => Megasweep.Detectors.Settings
  }

  def main(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [detector: :string, root: :string, jobs: :integer, out: :string, mode: :string]
      )

    detector_key = opts[:detector] || "nix-guix"
    detector = Map.get(@detectors, detector_key) || raise("unknown detector: #{detector_key}")
    root = (opts[:root] || "~/developer/repos") |> Path.expand()

    default_jobs = System.schedulers_online() * 4

    jobs =
      case opts[:jobs] do
        nil ->
          # Detectors that call remote APIs cap their own concurrency.
          if function_exported?(detector, :max_jobs, 0),
            do: min(default_jobs, detector.max_jobs()),
            else: default_jobs

        n ->
          n
      end
    mode = opts[:mode] || "audit"

    if mode != "audit" do
      IO.puts(:stderr, "megasweep: only --mode audit is implemented (report-only canary). Refusing #{mode}.")
      System.halt(2)
    end

    repos =
      root
      |> File.ls!()
      |> Enum.map(&Path.join(root, &1))
      |> Enum.filter(&Megasweep.Git.repo?/1)
      |> Enum.sort()

    t0 = System.monotonic_time(:millisecond)
    IO.puts("megasweep [#{detector.name()}] mode=audit root=#{root} repos=#{length(repos)} jobs=#{jobs}")

    results =
      repos
      |> Task.async_stream(fn r -> detector.detect(r, opts) end,
        max_concurrency: jobs,
        timeout: 120_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, res} -> res
        {:exit, _} -> nil
      end)
      |> Enum.reject(&is_nil/1)

    summary = detector.summarize(results)
    dt = System.monotonic_time(:millisecond) - t0

    IO.puts("\n=== SUMMARY (#{dt} ms) ===")
    summary |> Enum.each(fn {k, v} -> IO.puts("  #{k}: #{inspect(v)}") end)

    out = opts[:out] || "megasweep-#{detector.name()}.json"
    payload = %{detector: detector.name(), mode: mode, summary: summary, results: results}
    File.write!(out, JSON.encode!(payload))
    IO.puts("\nwrote #{out} (#{length(results)} repo records)")
  end
end

Megasweep.main(System.argv())
