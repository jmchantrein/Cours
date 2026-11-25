#!/bin/bash
# Un nouveau processus (bash -c, nohup…) n’hérite que de l’environnement :
# export transmet des valeurs, pas les attributs (readonly est perdu).

# shellcheck disable=SC2317  # appelée par bash -c, plus bas
___dans_un_autre_processus() {
    echo "  nouveau processus : je vois « ${_constante} »"
    _constante="modifiée sans protestation"
    echo "  readonly perdu : « ${_constante} »"
}

main() {
    local -r _constante="en lecture seule ici"
    export -f ___dans_un_autre_processus
    export _constante
    bash -c ___dans_un_autre_processus
    echo "main relit : « ${_constante} »"
}

main "$@"
