# SPDX-License-Identifier: PMPL-1.0
# Bash completion for bitfuckit

_bitfuckit() {
    local cur prev words cword
    _init_completion || return

    local commands="auth repo pr mirror tui help"
    local auth_cmds="login status"
    local repo_cmds="create list delete exists"
    local pr_cmds="list"

    case $cword in
        1)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)
            case ${words[1]} in
                auth)
                    COMPREPLY=($(compgen -W "$auth_cmds" -- "$cur"))
                    ;;
                repo)
                    COMPREPLY=($(compgen -W "$repo_cmds" -- "$cur"))
                    ;;
                pr)
                    COMPREPLY=($(compgen -W "$pr_cmds" -- "$cur"))
                    ;;
            esac
            ;;
        *)
            case ${words[1]} in
                repo)
                    case ${words[2]} in
                        create)
                            COMPREPLY=($(compgen -W "--private --description" -- "$cur"))
                            ;;
                    esac
                    ;;
                pr)
                    case ${words[2]} in
                        list)
                            COMPREPLY=($(compgen -W "--state --all" -- "$cur"))
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

complete -F _bitfuckit bitfuckit
