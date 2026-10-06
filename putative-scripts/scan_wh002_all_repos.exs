#!/usr/bin/env elixir
# scan_wh002_all_repos.exs - Scan all repos for WH002 (TokenPermissionsID) issues

System.put_env("GITHUB_TOKEN", "test_token")
Code.require_file("/home/hyperpolymath/developer/hyper-repos/hypatia/lib/rules/workflow_hardening.ex")

# Find all git repositories recursively
repos = 
  ["/home/hyperpolymath/developer/hyper-repos", "/home/hyperpolymath/developer/meta-repos"]
  |> Enum.flat_map(fn root ->
    # Walk the directory tree looking for .git directories or files
    find_repos(root, [])
  end)
  |> Enum.uniq()

defp find_repos(dir, acc) do
  case File.ls!(dir) do
    [] -> acc
    entries ->
      entries
      |> Enum.reduce(acc, fn entry, acc2 ->
        full_path = Path.join([dir, entry])
        
        cond do
          # It's a .git directory - parent is a repo
          String.ends_with?(entry, ".git") && File.dir?(full_path) ->
            repo_path = Path.dirname(full_path)
            if !Enum.member?(acc2, repo_path) do
              [repo_path | acc2]
            else
              acc2
            end
          
          # It's a directory - recurse
          File.dir?(full_path) ->
            # Skip certain directories
            if String.contains?(entry, ".migration-tmp") ||
               String.contains?(entry, "llm-coding-configs") ||
               String.contains?(entry, ".git") do
              acc2
            else
              find_repos(full_path, acc2)
            end
          
          true -> acc2
        end
      end)
  end
rescue
  _ -> acc
end

IO.puts("Scanning for TokenPermissionsID issues (WH002)...")
IO.puts("Found #{length(repos)} repositories\n")

all_findings = []
repos_with_issues = []

repos
|> Enum.with_index()
|> Enum.each(fn {repo, idx} ->
  workflow_dir = Path.join([repo, ".github", "workflows"])
  
  if File.dir?(workflow_dir) do
    findings = Hypatia.Rules.WorkflowHardening.wh002_excessive_permissions(repo)
    
    if length(findings) > 0 do
      repos_with_issues = [repo | repos_with_issues]
      all_findings = all_findings ++ Enum.map(findings, &%{&1 | repo: repo})
      
      IO.puts("[#{idx + 1}] #{Path.basename(repo)}: #{length(findings)} issue(s)")
      findings
      |> Enum.each(fn f ->
        IO.puts("    - #{f.file}: #{f.reason}")
      end)
      IO.puts("")
    end
  end
  
  # Progress indicator
  if (idx + 1) %% 100 == 0 do
    IO.puts("  ...scanned #{idx + 1} repos...")
  end
end)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("SUMMARY")
IO.puts(String.duplicate("=", 60))
IO.puts("Total repositories scanned: #{length(repos)}")
IO.puts("Repositories with WH002 issues: #{length(repos_with_issues)}")
IO.puts("Total WH002 findings: #{length(all_findings)}")
IO.puts("\nAffected repositories:")

repos_with_issues
|> Enum.sort()
|> Enum.each(&IO.puts/1)

# Save results to file
File.write!("/tmp/wh002_scan_results.json", Jason.encode!(all_findings))
IO.puts("\nResults saved to /tmp/wh002_scan_results.json")
