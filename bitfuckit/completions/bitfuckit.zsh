#compdef bitfuckit
# SPDX-License-Identifier: PMPL-1.0
# Zsh completion for bitfuckit

_bitfuckit() {
    local -a commands
    commands=(
        'auth:Manage authentication'
        'repo:Repository operations'
        'pr:Pull request operations'
        'mirror:Mirror repository to Bitbucket'
        'tui:Launch interactive TUI'
        'help:Show help'
    )

    local -a auth_commands
    auth_commands=(
        'login:Authenticate with Bitbucket'
        'status:Show authentication status'
    )

    local -a repo_commands
    repo_commands=(
        'create:Create a new repository'
        'list:List all repositories'
        'delete:Delete a repository'
        'exists:Check if repository exists'
    )

    local -a pr_commands
    pr_commands=(
        'list:List pull requests for a repository'
    )

    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '*: :->args'

    case $state in
        command)
            _describe -t commands 'bitfuckit commands' commands
            ;;
        subcommand)
            case $words[2] in
                auth)
                    _describe -t auth_commands 'auth commands' auth_commands
                    ;;
                repo)
                    _describe -t repo_commands 'repo commands' repo_commands
                    ;;
                pr)
                    _describe -t pr_commands 'pr commands' pr_commands
                    ;;
            esac
            ;;
        args)
            case $words[2] in
                repo)
                    case $words[3] in
                        create)
                            _arguments \
                                '--private[Make repository private]' \
                                '--description[Set repository description]:description:'
                            ;;
                    esac
                    ;;
                pr)
                    case $words[3] in
                        list)
                            _arguments \
                                '1:repository name:' \
                                '--state[Filter by state]:state:(OPEN MERGED DECLINED SUPERSEDED)' \
                                '--all[Show all pull requests]'
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

_bitfuckit "$@"
