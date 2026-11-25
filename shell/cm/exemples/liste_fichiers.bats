#!/usr/bin/env bats
# Tests de liste_fichiers.bash : les réponses « au clavier » arrivent par <<<

@test "liste les fichiers d’un répertoire" {
    run bash "$BATS_TEST_DIRNAME/liste_fichiers.bash" <<< "$BATS_TEST_DIRNAME/donnees"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fichier : $BATS_TEST_DIRNAME/donnees/pionnieres.csv"* ]]
}

@test "code 1 si le répertoire n’existe pas" {
    run bash "$BATS_TEST_DIRNAME/liste_fichiers.bash" <<< "/nulle/part"
    [ "$status" -eq 1 ]
}
