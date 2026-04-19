#!/usr/bin/env julia
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# gitlink-drift.jl — classify submodule-gitlink drift across a meta-repo tree.
#
# This replaces a prior one-shot tool whose "summary counters mismatch" bug
# (AI-WORK-todo.md §4) came from a single call to
#   git submodule status --recursive
# at the meta-repo root. That primitive aborts on the first broken submodule
# declaration (e.g. `.git-private-farm` in /var/mnt/eclipse/repos lacks a URL
# in .gitmodules, so git prints "fatal: no submodule mapping found for path
# '.git-private-farm'" to stderr and exits. Any entries that would have
# followed are never enumerated). A tool that counted from another source
# (e.g. directory walk) while aggregating from this broken stdout produces
# category counts that do not sum to the declared total. The fix is not to
# trust submodule-status as the authoritative enumerator: walk .gitmodules
# files directly and classify each declared path individually.
#
# Output: A2ML (per estate rule: tools emit A2ML/Nickel, never JSON).
# Invariant: the sum of per-category counts MUST equal the declared total;
# violation is an assertion error, not a silent miscount.
#
# Usage:
#   julia reposystem/scripts/gitlink-drift.jl [ROOT]
# ROOT defaults to /var/mnt/eclipse/repos.

using Dates
using Printf

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

# One declared submodule, pre-classification. `parent` is the repo that
# declares it in its .gitmodules; `path` is the submodule's path relative
# to `parent`. `url` may be nothing when .gitmodules declares the entry
# without a URL (the case that kills `git submodule status --recursive`).
struct Submodule
    parent::String           # absolute path of declaring repo
    path::String             # relative path under parent
    url::Union{String, Nothing}
end

# Classification outcome. `status` is the first-pass bucket from submodule
# status prefix. For :CHANGED, `direction` refines into :AHEAD / :BEHIND /
# :DIVERGED / :UNKNOWN (last when the relationship cannot be computed).
# `gitlink_sha` is the SHA recorded in the parent tree; `head_sha` is the
# submodule HEAD actually on disk. Either may be empty on error paths.
struct Classification
    submodule::Submodule
    status::Symbol           # :SAME | :CHANGED | :NOT_INITIALIZED | :CONFLICTED
                             # | :URL_MISSING | :UNREACHABLE
    direction::Symbol        # :NA for non-:CHANGED; otherwise :AHEAD/:BEHIND/:DIVERGED/:UNKNOWN
    gitlink_sha::String      # parent's recorded sha for the path
    head_sha::String         # submodule's current HEAD sha
    note::String             # error text / context for non-clean outcomes
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Run a shell command, return (stdout, stderr, exit_code) all as Strings.
# Used instead of `read(`...`, String)` because we need to distinguish
# "empty stdout because nothing to say" from "empty stdout because stderr
# fatal aborted recursion".
function run_capture(cmd::Cmd)::Tuple{String, String, Int}
    out = IOBuffer()
    err = IOBuffer()
    proc = run(pipeline(ignorestatus(cmd); stdout=out, stderr=err))
    return (String(take!(out)), String(take!(err)), proc.exitcode)
end

# Enumerate all .gitmodules files reachable from `root` by recursive
# directory walk. We skip `.git/` directories to avoid descending into
# superproject worktree metadata. The walk is authoritative: it finds
# everything declared anywhere in the tree, regardless of whether any
# particular git command is willing to enumerate it.
function find_gitmodules(root::AbstractString)::Vector{String}
    results = String[]
    for (dir, subdirs, files) in walkdir(root; follow_symlinks=false)
        # prune .git/ dirs in-place (saves a lot of walking)
        filter!(d -> d != ".git", subdirs)
        if ".gitmodules" in files
            push!(results, joinpath(dir, ".gitmodules"))
        end
    end
    return results
end

# Parse a .gitmodules file via `git config --file` rather than regex — git
# already knows the exact syntax (sections, continuations, escapes), so
# we outsource. Returns one Submodule per declared entry. A declared entry
# without a URL still counts — it is a real submodule we need to classify
# as :URL_MISSING rather than silently drop.
function parse_gitmodules(gitmod_path::AbstractString)::Vector{Submodule}
    parent_dir = dirname(gitmod_path)

    paths_out, _, paths_exit = run_capture(
        `git config --file $gitmod_path --get-regexp "^submodule\..*\.path\$"`)
    paths_exit != 0 && return Submodule[]

    urls_out, _, _ = run_capture(
        `git config --file $gitmod_path --get-regexp "^submodule\..*\.url\$"`)

    # Build name -> url map. Keys look like `submodule.<NAME>.url`.
    url_map = Dict{String, String}()
    for line in split(urls_out, '\n'; keepempty=false)
        key, val = split(line, ' '; limit=2)
        name = match(r"^submodule\.(.*)\.url$", key)
        if name !== nothing
            url_map[String(name.captures[1])] = String(val)
        end
    end

    subs = Submodule[]
    for line in split(paths_out, '\n'; keepempty=false)
        key, path_val = split(line, ' '; limit=2)
        name_match = match(r"^submodule\.(.*)\.path$", key)
        name_match === nothing && continue
        name = String(name_match.captures[1])
        push!(subs, Submodule(parent_dir, String(path_val), get(url_map, name, nothing)))
    end
    return subs
end

# Classify a single submodule entry. Strategy: never invoke
# `git submodule status --recursive` — invoke the non-recursive
# per-path variant so a broken sibling can't abort the classification.
# Fall through to direct git-plumbing for the deepest detail.
function classify(sub::Submodule)::Classification
    abspath_ = joinpath(sub.parent, sub.path)

    # --- URL missing: .gitmodules declares path but no URL. This is the
    # specific drift case that kills the naive --recursive approach.
    if sub.url === nothing
        gitmod_file = joinpath(sub.parent, ".gitmodules")
        return Classification(sub, :URL_MISSING, :NA, "", "",
            "no url declared in $gitmod_file")
    end

    # --- Gitlink SHA recorded in parent's tree. Using rev-parse on
    # HEAD:<path> treats a submodule as a tree object and returns its
    # recorded SHA. If parent HEAD has no such entry the submodule is
    # declared but not tracked; surface that as :UNREACHABLE.
    gl_out, gl_err, gl_exit = run_capture(
        Cmd(`git -C $(sub.parent) rev-parse HEAD:$(sub.path)`))
    if gl_exit != 0
        return Classification(sub, :UNREACHABLE, :NA, "", "",
            "parent rev-parse failed: $(strip(gl_err))")
    end
    gitlink_sha = strip(gl_out)

    # --- Submodule working-tree HEAD. If the path isn't a git repo
    # (never initialised, or removed), classify :NOT_INITIALIZED.
    if !isdir(joinpath(abspath_, ".git")) && !isfile(joinpath(abspath_, ".git"))
        return Classification(sub, :NOT_INITIALIZED, :NA, gitlink_sha, "",
            "no .git at $abspath_")
    end

    hd_out, hd_err, hd_exit = run_capture(
        Cmd(`git -C $abspath_ rev-parse HEAD`))
    if hd_exit != 0
        return Classification(sub, :UNREACHABLE, :NA, gitlink_sha, "",
            "submodule rev-parse failed: $(strip(hd_err))")
    end
    head_sha = strip(hd_out)

    # --- Conflicted? `git status --porcelain=v1` inside parent for this
    # path shows "UU" for an unmerged submodule pointer.
    st_out, _, _ = run_capture(
        Cmd(`git -C $(sub.parent) status --porcelain=v1 -- $(sub.path)`))
    if occursin(r"^UU |^AA |^DD ", st_out)
        return Classification(sub, :CONFLICTED, :NA, gitlink_sha, head_sha,
            "unmerged: $(strip(st_out))")
    end

    # --- Same sha? Nothing to do.
    if head_sha == gitlink_sha
        return Classification(sub, :SAME, :NA, gitlink_sha, head_sha, "")
    end

    # --- Changed. Direction via merge-base ancestry in the submodule repo.
    # NB: --is-ancestor returns exit 0 when the first arg IS an ancestor
    # of the second, exit 1 when it isn't, exit >1 on plumbing error.
    _, _, gl_anc = run_capture(
        Cmd(`git -C $abspath_ merge-base --is-ancestor $gitlink_sha $head_sha`))
    _, _, hd_anc = run_capture(
        Cmd(`git -C $abspath_ merge-base --is-ancestor $head_sha $gitlink_sha`))

    direction = if gl_anc == 0 && hd_anc != 0
        :AHEAD               # gitlink is an ancestor of HEAD → HEAD has new commits
    elseif hd_anc == 0 && gl_anc != 0
        :BEHIND              # HEAD is ancestor of gitlink → gitlink has new commits the submodule doesn't
    elseif gl_anc == 0 && hd_anc == 0
        :SAME                # degenerate — both ancestors means equal, but we already checked equal above
    elseif gl_anc > 1 || hd_anc > 1
        :UNKNOWN             # plumbing error (shas missing locally, e.g. unfetched)
    else
        :DIVERGED            # neither is an ancestor of the other
    end

    return Classification(sub, :CHANGED, direction, gitlink_sha, head_sha, "")
end

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

# Emit A2ML per memory rule (no JSON emit). The summary counters are
# printed ONCE from a single dict — structurally impossible for the
# summary to disagree with the detail section that iterates the same dict.
# This replaces the old counters-bug where two different collection paths
# contributed to two different totals.
function emit_a2ml(root::String, classifications::Vector{Classification}, io::IO=stdout)
    buckets = Dict{Symbol, Vector{Classification}}()
    for cls in classifications
        bucket_key = cls.status === :CHANGED ? cls.direction : cls.status
        push!(get!(buckets, bucket_key, Classification[]), cls)
    end

    total = length(classifications)
    # Invariant that was broken in the previous tool: summary must sum to total.
    bucket_total = sum(length(v) for v in values(buckets); init=0)
    bucket_total == total || error(
        "aggregation invariant violated: buckets sum to $bucket_total, enumerated $total")

    println(io, "# SPDX-License-Identifier: PMPL-1.0-or-later")
    println(io, "# gitlink-drift report — generated $(Dates.now())")
    println(io, "")
    println(io, "[report]")
    println(io, "root = \"$root\"")
    println(io, "generated-at = \"$(Dates.now())\"")
    println(io, "total-submodules-declared = $total")
    println(io, "")
    println(io, "[summary]")
    # Stable ordering so diffs across runs are meaningful.
    for key in [:SAME, :AHEAD, :BEHIND, :DIVERGED, :UNKNOWN,
                :NOT_INITIALIZED, :CONFLICTED, :URL_MISSING, :UNREACHABLE]
        count = length(get(buckets, key, Classification[]))
        println(io, "$(lowercase(String(key))) = $count")
    end
    println(io, "")

    # Detail section: every non-SAME entry, grouped by bucket.
    for key in [:AHEAD, :BEHIND, :DIVERGED, :UNKNOWN,
                :NOT_INITIALIZED, :CONFLICTED, :URL_MISSING, :UNREACHABLE]
        entries = get(buckets, key, Classification[])
        isempty(entries) && continue
        println(io, "[[$(lowercase(String(key)))]]")
        for cls in entries
            rel = relpath(joinpath(cls.submodule.parent, cls.submodule.path), root)
            println(io, "path = \"$rel\"")
            println(io, "gitlink-sha = \"$(cls.gitlink_sha)\"")
            println(io, "head-sha = \"$(cls.head_sha)\"")
            isempty(cls.note) || println(io, "note = \"$(replace(cls.note, '"' => "\\\""))\"")
            println(io, "")
        end
    end
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

function main(args::Vector{String})
    root = isempty(args) ? "/var/mnt/eclipse/repos" : abspath(args[1])
    isdir(root) || error("root $root is not a directory")

    @info "Enumerating .gitmodules under $root…"
    gitmod_files = find_gitmodules(root)
    @info "Found $(length(gitmod_files)) .gitmodules files"

    submodules = Submodule[]
    for gm in gitmod_files
        append!(submodules, parse_gitmodules(gm))
    end
    @info "Declared submodules: $(length(submodules))"

    classifications = Classification[]
    for (i, sub) in enumerate(submodules)
        if i % 50 == 0
            @info "classified $i/$(length(submodules))…"
        end
        push!(classifications, classify(sub))
    end

    emit_a2ml(root, classifications)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
