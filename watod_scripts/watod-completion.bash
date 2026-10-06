#!/usr/bin/env bash
# Adapted from WATonomous/wato_f1tenth main at 4aa2c4a and its Docker Compose
# completion (https://github.com/docker/compose/tree/1.28.5/contrib/completion).
# Changes: use current watod arguments and Compose service discovery.
_watod_complete() {
    local current previous command word services
    current="${COMP_WORDS[COMP_CWORD]}"
    previous="${COMP_WORDS[COMP_CWORD-1]}"
    command=""
    for word in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
        case "$word" in
            build|config|down|exec|images|logs|ps|pull|push|restart|run|stop|up)
                command="$word"
                break
                ;;
        esac
    done
    COMPREPLY=()
    case "$previous" in
        -t|--terminal|-d|--setup-dev-env)
            services="$("${COMP_WORDS[0]}" config --services 2>/dev/null)"
            mapfile -t COMPREPLY < <(compgen -W "$services" -- "$current")
            return
            ;;
    esac
    if [[ "$current" == -* ]]; then
        case "$command" in
            up) word='-d --build --force-recreate --remove-orphans' ;;
            build) word='--no-cache --pull --progress' ;;
            run) word='--rm --no-deps -T --entrypoint' ;;
            exec) word='-T --user --workdir' ;;
            *) word='--help --verbose --terminal --setup-dev-env --setup-completion' ;;
        esac
        mapfile -t COMPREPLY < <(compgen -W "$word" -- "$current")
    elif [[ -z "$command" ]]; then
        mapfile -t COMPREPLY < <(compgen -W \
            'build config down exec images logs ps pull push restart run stop up' -- "$current")
    else
        services="$("${COMP_WORDS[0]}" config --services 2>/dev/null)"
        mapfile -t COMPREPLY < <(compgen -W "$services" -- "$current")
    fi
}
complete -F _watod_complete watod ./watod
