#!/bin/bash
# local ne veut pas dire « local à la fonction » : la portée de Bash est
# dynamique, la variable est visible et modifiable dans les fonctions appelées.

___visiteuse() {
    echo "  ___visiteuse voit : « ${_locale} »"
    _locale="modifiée par ___visiteuse"
}

main() {
    local _locale="déclarée dans main"
    ___visiteuse
    echo "de retour dans main : « ${_locale} »"
}

main "$@"
