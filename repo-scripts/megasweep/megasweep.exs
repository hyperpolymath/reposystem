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
# v1 ships the NixGuix detector (reposystem#138/#139). Add more by dropping a
# module in @detectors. APPLY mode is intentionally NOT implemented yet:
# megasweep is an audit/report-only canary first (mutation lands later, owner-gated).
#
# Usage:
#   elixir megasweep.exs [--detector nix-guix] [--root ~/developer/repos]
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

defmodule Megasweep do
  @detectors %{"nix-guix" => Megasweep.Detectors.NixGuix}

  def main(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [detector: :string, root: :string, jobs: :integer, out: :string, mode: :string]
      )

    detector_key = opts[:detector] || "nix-guix"
    detector = Map.get(@detectors, detector_key) || raise("unknown detector: #{detector_key}")
    root = (opts[:root] || "~/developer/repos") |> Path.expand()
    jobs = opts[:jobs] || System.schedulers_online() * 4
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
