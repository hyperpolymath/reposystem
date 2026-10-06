#!/usr/bin/env elixir
# scan_token_permissions.exs - Scan all repos for TokenPermissionsID issues using WH002

System.put_env("GITHUB_TOKEN", "dummy_token_for_local_scan")

Code.require_file("/home/hyperpolymath/developer/hyper-repos/hypatia/lib/rules/workflow_hardening.ex")

repo_roots = [
  "/home/hyperpolymath/developer/hyper-repos",
  "/home/hyperpolymath/developer/meta-repos"
]

findings_by_repo = % {}

# Find all repos
repo_roots
|> Enum.flat_map(fn root ->
  case File.ls!(root) do
    files ->
      files
      |> Enum.filter(&File.dir?(&1))
      |> Enum.flat_map(fn dir ->
        full_path = Path.join([root, dir])
        
        # Check if it's a git repo
        if File.exists?(Path.join([full_path, ".git"])) do
          [full_path]
        else
          # Check subdirectories for .git
          case File.ls!(full_path) do
            subfiles ->
              subfiles
              |> Enum.filter(&File.dir?(&1))
              |> Enum.map(fn subdir ->
                subpath = Path.join([full_path, subdir])
                if File.exists?(Path.join([subpath, ".git"])) do
                  subpath
                else
                  nil
                end
              end)
              |> Enum.reject(&(&1 == nil))
            _ -> []
          end
        end
      end)
    _ -> []
  end
end)
|> Enum.uniq()
|> Enum.reject(fn path ->
  # Skip non-directories
  !File.dir?(path) ||
  # Skip known non-repo directories
  String.contains?(path, ".migration-tmp") ||
  String.contains?(path, "llm-coding-configs")
end)
|> IO.inspect(label: "Found repos")

# Now scan each repo for WH002 issues
all_findings = []

repo_list = File.ls!("/home/hyperpolymath/developer/hyper-repos")
           ++ File.ls!("/home/hyperpolymath/developer/meta-repos")

IO.puts("Scanning repos for TokenPermissionsID issues...")

repo_list
|> Enum.filter(&File.dir?(&1))
|> Enum.take(10)  # Limit to 10 for testing
|> Enum.each(fn dir ->
  repo_roots
  |> Enum.each(fn root ->
    full_path = Path.join([root, dir])
    
    if File.dir?(full_path) do
      workflow_dir = Path.join([full_path, ".github", "workflows"])
      
      if File.dir?(workflow_dir) do
        findings = Hypatia.Rules.WorkflowHardening.wh002_excessive_permissions(full_path)
        
        if length(findings) > 0 do
          IO.puts("\n=== #{dir} ===")
          findings
          |> Enum.each(fn f ->
            IO.puts("  #{f.file}: #{f.reason}")
          end)
          all_findings = all_findings ++ findings
        end
      end
    end
  end)
end)

IO.puts("\n=== Summary ===")
IO.puts("Total findings: #{length(all_findings)}")
