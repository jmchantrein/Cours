#!/bin/bash
# Même fonction, deux contextes : appel direct (variables partagées),
# puis sous-shell ( … ) : une copie, que les modifications ne quittent pas.

___visiteuse() {
    echo "  BASHPID=${BASHPID} : je vois « ${_locale} »"
    _locale="modifiée par ___visiteuse"
}

main() {
    local _locale="déclarée dans main"
    echo "main : \$\$=$$, BASHPID=${BASHPID}"
    echo "— appel direct :"
    ___visiteuse
    echo "main relit : « ${_locale} »"
    _locale="déclarée dans main"
    echo "— appel en sous-shell :"
    ( ___visiteuse )
    echo "main relit : « ${_locale} »"
}

main "$@"
