#!/usr/bin/env bats
# Tests des corrigés du TP « Du pipeline au script robuste ».
# Chaque test part d’un atelier neuf, dans le dossier temporaire que Bats lui donne : donnees/
# contient pionnieres.csv et services.conf. Les réponses « au clavier » arrivent par <<<.
# Lancer : bats solutions.bats (depuis n’importe quel dossier).
# shellcheck disable=SC2154  # $stderr est rempli par run --separate-stderr

# run --separate-stderr demande Bats 1.5 ou plus récent.
bats_require_minimum_version 1.5.0

setup() {
    corrige="$BATS_TEST_DIRNAME"
    cd "$BATS_TEST_TMPDIR" || return
    mkdir donnees
    cp "$corrige/donnees/pionnieres.csv" "$corrige/donnees/services.conf" donnees/
}

# ---------- Étape 2 : les pipelines ----------

@test "pipelines.sh : sorties attendues (attendu/pipelines.txt)" {
    run bash "$corrige/pipelines.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$corrige/attendu/pipelines.txt")" ]
}

@test "pipelines.sh : la sortie de cut dans noms.txt, son erreur dans erreurs.txt" {
    run bash "$corrige/pipelines.sh"
    [ "$(head -n 1 noms.txt)" = "nom" ]
    [ "$(wc -l < noms.txt)" -eq 9 ]
    grep -q 'absent.csv' erreurs.txt
    run grep -c 'absent.csv' noms.txt
    [ "$output" -eq 0 ]
}

# ---------- Étape 3 : liste_fichiers.bash ----------

@test "liste_fichiers : liste les fichiers d’un répertoire, code 0" {
    run bash "$corrige/liste_fichiers.bash" <<< "donnees"
    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "Fichier : donnees/pionnieres.csv" ]
    [ "${lines[2]}" = "Fichier : donnees/services.conf" ]
}

@test "liste_fichiers : code 1 et message sur l’erreur standard si le répertoire n’existe pas" {
    run --separate-stderr bash "$corrige/liste_fichiers.bash" <<< "/nulle/part"
    [ "$status" -eq 1 ]
    [ "$stderr" = "Le répertoire /nulle/part n’existe pas." ]
    [ "$output" = "Entrez le chemin du répertoire :" ]
}

@test "liste_fichiers : un nom de répertoire à espace" {
    mkdir "mes données"
    touch "mes données/notes de cours.txt"
    run bash "$corrige/liste_fichiers.bash" <<< "mes données"
    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "Fichier : mes données/notes de cours.txt" ]
}

# ---------- Étape 4 : copie_fichiers.bash et ses codes de retour ----------

@test "copie_fichiers : crée la destination et copie, code 0" {
    run bash "$corrige/copie_fichiers.bash" <<< $'donnees\ncopie'
    [ "$status" -eq 0 ]
    diff -r donnees copie
}

@test "copie_fichiers : code 1 si la source n’existe pas" {
    run bash "$corrige/copie_fichiers.bash" <<< $'absent\ncopie'
    [ "$status" -eq 1 ]
    [ ! -e copie ]
}

@test "copie_fichiers : code 2 si la destination ne peut pas être créée" {
    run bash "$corrige/copie_fichiers.bash" <<< $'donnees\ndonnees/pionnieres.csv/copie'
    [ "$status" -eq 2 ]
}

@test "copie_fichiers : code 3 si la copie échoue (source vide)" {
    mkdir vide
    run bash "$corrige/copie_fichiers.bash" <<< $'vide\ncopie'
    [ "$status" -eq 3 ]
}

# ---------- Étape 5 : a-relire.sh, corrigé ----------

@test "a-relire.sh corrigé : trouve rapport.txt dans un dossier à espace" {
    mkdir "mes documents"
    touch "mes documents/rapport.txt" "mes documents/notes de cours.txt"
    run bash "$corrige/a-relire.sh" "mes documents"
    [ "$status" -eq 0 ]
    [ "$output" = "Trouvé : rapport.txt" ]
}

# ---------- Étapes 7 et 8 : arguments, set -euo pipefail, main ----------
# Les deux versions doivent se comporter de la même façon : les mêmes tests valent pour l’une et l’autre.

versions=(copie_fichiers_args.bash copie_fichiers_robuste.bash)

@test "versions à arguments : code 4 et usage sur l’erreur standard sans argument" {
    for script in "${versions[@]}"; do
        run --separate-stderr bash "$corrige/$script"
        [ "$status" -eq 4 ]
        [[ "$stderr" == "Usage : "*" SOURCE DESTINATION" ]]
        [ -z "$output" ]
    done
}

@test "versions à arguments : code 4 avec un seul ou trois arguments" {
    for script in "${versions[@]}"; do
        run bash "$corrige/$script" donnees
        [ "$status" -eq 4 ]
        run bash "$corrige/$script" donnees copie en-trop
        [ "$status" -eq 4 ]
    done
}

@test "versions à arguments : copie, code 0, contenu identique" {
    for script in "${versions[@]}"; do
        run bash "$corrige/$script" donnees "copie $script"
        [ "$status" -eq 0 ]
        [ "${lines[1]}" = "Les fichiers ont été copiés de donnees vers copie $script." ]
        diff -r donnees "copie $script"
    done
}

@test "versions à arguments : codes 1, 2 et 3" {
    mkdir vide
    for script in "${versions[@]}"; do
        run bash "$corrige/$script" absent copie
        [ "$status" -eq 1 ]
        run bash "$corrige/$script" donnees donnees/pionnieres.csv/copie
        [ "$status" -eq 2 ]
        run bash "$corrige/$script" vide "copie vide"
        [ "$status" -eq 3 ]
    done
}

@test "versions à arguments : ne lisent pas l’entrée standard" {
    for script in "${versions[@]}"; do
        run bash "$corrige/$script" donnees copie <<< $'absent\nautre'
        [ "$status" -eq 0 ]
        [ ! -e autre ]
    done
}
