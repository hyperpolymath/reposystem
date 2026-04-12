% SPDX-License-Identifier: PMPL-1.0-or-later
% Security Error Knowledge Base for GitHub Workflows
% Designed for use with Virtuoso Open Source and Qwen3 SLM augmentation

:- object(security_error_catalog).

    :- info([
        version is 1:1:0,
        author is 'hyperpolymath',
        date is 2026-01-04,
        comment is 'Catalog of GitHub workflow security errors and fixes'
    ]).

    % Error severity levels
    :- public(severity/2).
    severity(critical, 'Must fix immediately - blocks CI or exposes vulnerabilities').
    severity(high, 'Should fix soon - security risk or OpenSSF compliance issue').
    severity(medium, 'Should fix - code quality or maintainability issue').
    severity(low, 'Nice to fix - minor improvements').

    % Error categories
    :- public(category/2).
    category(workflow, 'GitHub Actions workflow configuration issues').
    category(security, 'Security vulnerabilities or misconfigurations').
    category(license, 'Licensing and SPDX header issues').
    category(language, 'Language detection and tooling issues').

    % Error definitions
    :- public(error/5).
    % error(ID, Category, Severity, Description, AutoFixable)

    error('ERR-WF-001', workflow, medium, 'Duplicate CodeQL workflows (codeql.yml AND codeql-analysis.yml)', true).
    error('ERR-WF-002', workflow, high, 'CodeQL language matrix mismatch - scanning languages not in repo', true).
    error('ERR-WF-003', workflow, medium, 'Broken comprehensive-quality.yml workflow', true).
    error('ERR-WF-004', workflow, low, 'Mirror workflow missing SSH key secrets', false).
    error('ERR-WF-005', workflow, low, 'Datadog workflow without API credentials', true).
    error('ERR-WF-006', workflow, high, 'Invalid action SHA - action not found at pinned commit', true).
    error('ERR-WF-007', workflow, medium, 'Composite action uses unpinned internal dependencies', false).
    error('ERR-WF-008', workflow, high, 'Bad editorconfig-checker SHA (8c9b118d is invalid, use 4b6cd619)', true).
    error('ERR-WF-009', workflow, high, 'Invalid CodeQL actions language - use javascript-typescript instead', true).
    error('ERR-WF-010', workflow, medium, 'GitHub Pages not enabled on SSG repos', false).

    error('ERR-SEC-001', security, high, 'Unpinned GitHub Actions - using version tags instead of SHA', true).
    error('ERR-SEC-002', security, high, 'Missing workflow permissions declaration', true).
    error('ERR-SEC-003', security, medium, 'Secrets referenced without conditional guards', true).

    error('ERR-LIC-001', license, medium, 'Missing SPDX-License-Identifier header in workflow', true).

    % Fix patterns
    :- public(fix/3).
    % fix(ErrorID, Pattern, Replacement)

    fix('ERR-SEC-001', 'uses: ACTION@VERSION', 'uses: ACTION@SHA # VERSION').
    fix('ERR-SEC-002', '(no permissions)', 'permissions: read-all').
    fix('ERR-LIC-001', '(file start)', '# SPDX-License-Identifier: PMPL-1.0-or-later').
    fix('ERR-WF-008', '8c9b118d446fce7e6410b6c0a3ce2f83bd04e97a', '4b6cd6190d435e7e084fb35e36a096e98506f7b9').
    fix('ERR-WF-009', 'language: actions', 'language: javascript-typescript').
    fix('ERR-WF-010', '(API call)', 'gh api --method POST repos/OWNER/REPO/pages -f build_type=workflow').

    % SHA pinning reference table
    :- public(pinned_sha/3).
    % pinned_sha(Action, Version, SHA)

    pinned_sha('actions/checkout', 'v4.2.2', '11bd71901bbe5b1630ceea73d27597364c9af683').
    pinned_sha('github/codeql-action/init', 'v3', '662472033e021d55d94146f66f6058822b0b39fd').
    pinned_sha('github/codeql-action/analyze', 'v3', '662472033e021d55d94146f66f6058822b0b39fd').
    pinned_sha('ossf/scorecard-action', 'v2.4.0', '62b2cac7ed8198b15735ed49ab1e5cf35480ba46').
    pinned_sha('trufflesecurity/trufflehog', 'v3', '05cccb53bc9e13bc6d17997db5a6bcc3df44bf2f').
    pinned_sha('webfactory/ssh-agent', 'v0.9.1', 'a6f90b1f127823b31d4d4a8d96047790581349bd').
    pinned_sha('editorconfig-checker/action-editorconfig-checker', 'v2.1.0', '4b6cd6190d435e7e084fb35e36a096e98506f7b9').
    pinned_sha('dtolnay/rust-toolchain', 'stable', '6d9817901c499d6b02debbb57edb38d33daa680b').
    pinned_sha('Swatinem/rust-cache', 'v2', 'ad397744b0d591a723ab90405b7247fac0e6b8db').
    pinned_sha('codecov/codecov-action', 'v5', '671740ac38dd9b0130fbe1cec585b89eea48d3de').
    pinned_sha('actions/configure-pages', 'v5', '983d7736d9b0ae728b81ab479565c72886d7745b').
    pinned_sha('actions/jekyll-build-pages', 'v1', '44a6e6beabd48582f863aeeb6cb2151cc1716697').
    pinned_sha('actions/upload-pages-artifact', 'v3', '56afc609e74202658d3ffba0e8f6dda462b719fa').
    pinned_sha('actions/deploy-pages', 'v4', 'd6db90164ac5ed86f2b6aed7e0febac5b3c0c03e').

    % CodeQL language detection rules
    :- public(codeql_language/2).
    % codeql_language(FileExtensions, Language)

    codeql_language(['.js', '.jsx', '.ts', '.tsx', '.mjs'], 'javascript-typescript').
    codeql_language(['.py'], 'python').
    codeql_language(['.go'], 'go').
    codeql_language(['.java', '.kt'], 'java-kotlin').
    codeql_language(['.rb'], 'ruby').
    codeql_language(['.cs'], 'csharp').
    codeql_language(['.cpp', '.c', '.h'], 'cpp').
    codeql_language(['.swift'], 'swift').

    % Languages NOT supported by CodeQL (use javascript-typescript as fallback)
    :- public(codeql_unsupported/1).
    codeql_unsupported('rust').     % Use javascript-typescript if JS present, else remove CodeQL
    codeql_unsupported('ocaml').    % Use javascript-typescript if JS present, else remove CodeQL
    codeql_unsupported('haskell').  % Use javascript-typescript if JS present, else remove CodeQL
    codeql_unsupported('elixir').   % Use javascript-typescript if JS present, else remove CodeQL
    codeql_unsupported('nickel').   % Use javascript-typescript if JS present, else remove CodeQL
    codeql_unsupported('actions').  % INVALID - 'actions' is not a valid CodeQL language (ERR-WF-009)

    % Query helpers
    :- public(get_critical_errors/1).
    get_critical_errors(Errors) :-
        findall(ID-Desc, (error(ID, _, critical, Desc, _)), Errors).

    :- public(get_auto_fixable/1).
    get_auto_fixable(Errors) :-
        findall(ID-Desc, (error(ID, _, _, Desc, true)), Errors).

    :- public(get_sha_for_action/3).
    get_sha_for_action(Action, Version, SHA) :-
        pinned_sha(Action, Version, SHA).

:- end_object.
