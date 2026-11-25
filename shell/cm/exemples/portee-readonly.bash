#!/bin/bash
# local -r : la fonction appelée voit la constante, mais ne peut pas la modifier.

___tente_de_modifier() {
    echo "  je vois : « ${_constante} »"
    _constante="tentative de modification"
    echo "  cette ligne ne s’affiche pas"
}

main() {
    local -r _constante="gravée dans main"
    ___tente_de_modifier
    echo "suite de main : ne s’affiche pas non plus"
}

main "$@"
echo "suite du script, code de retour de main : $?"
