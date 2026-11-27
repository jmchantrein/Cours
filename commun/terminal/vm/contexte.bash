# shellcheck shell=bash
# /etc/cours-contexte.bash de la VM du terminal, lu par /etc/profile.d/cours.sh (Bash seulement).
# Après chaque commande, juste avant l'invite, le shell décrit où il est, dans une séquence invisible que la page lit
# (commun/terminal/contexte.js) pour dessiner l'arbre de contexte : rien ne s'affiche dans le terminal.
#
#   ESC ] 6973 ; v1 ␟ <répertoire courant> ␟ <répertoire personnel> ␟ <répertoire précédent> ␞ <dossier> ␞ … BEL
#   <dossier> = <chemin> ␟ <nombre d'entrées> ␟ <nom> ␟ <nom>/ …     (« / » final : un répertoire ; « - » : illisible)
# Les séparateurs ␟ et ␞ (U+241F, U+241E) sont imprimables : un terminal ignore les caractères de commande dans une
# séquence OSC. Dans un nom, ils deviennent « ? », comme les caractères de commande.
#
# Dossiers décrits : le répertoire personnel et ses sous-répertoires sur trois niveaux, le répertoire courant et ses
# sous-répertoires, ses ancêtres jusqu'à la racine. Au plus 40 noms par dossier et 60 dossiers. Tout se fait par des
# commandes internes de Bash (développement des chemins, test -d), sans lancer de processus : environ 0,2 s dans la VM.
__cours_dossier() {   # $1 chemin  $2 profondeur
  local d=$1 e nom rec
  local -a liste enfants=()
  (( ${#__cours_dossiers[@]} >= 60 )) && return
  [[ ${__cours_vus[$d]:--1} -ge $2 ]] && return
  __cours_vus[$d]=$2
  if [[ -r $d && -x $d ]]; then
    liste=("${d%/}"/*)
    rec=${d//[[:cntrl:]␟␞]/?}␟${#liste[@]}
    for e in "${liste[@]:0:40}"; do
      nom=${e##*/}
      nom=${nom//[[:cntrl:]␟␞]/?}
      if [[ -d $e ]]; then
        rec+=␟$nom/
        [[ -L $e ]] || enfants+=("$e")
      else
        rec+=␟$nom
      fi
    done
  else
    rec=${d//[[:cntrl:]␟␞]/?}␟-
  fi
  __cours_dossiers+=("$rec")
  if (( $2 > 0 )); then
    for e in "${enfants[@]}"; do __cours_dossier "$e" $(( $2 - 1 )); done
  fi
}

__cours_contexte() {
  local code=$? p
  local -a __cours_dossiers=()
  local -A __cours_vus=()
  local nullglob=0 dotglob=0
  shopt -q nullglob && nullglob=1
  shopt -q dotglob && dotglob=1
  shopt -s nullglob dotglob
  [[ -d $HOME ]] && __cours_dossier "$HOME" 3
  __cours_dossier "$PWD" 1
  p=$PWD
  while [[ $p == /?* ]]; do
    p=${p%/*}
    __cours_dossier "${p:-/}" 0
  done
  (( nullglob )) || shopt -u nullglob
  (( dotglob )) || shopt -u dotglob
  local IFS=␞
  printf '\033]6973;v1␟%s␟%s␟%s␞%s\007' "${PWD//[[:cntrl:]␟␞]/?}" "${HOME//[[:cntrl:]␟␞]/?}" \
    "${OLDPWD//[[:cntrl:]␟␞]/?}" "${__cours_dossiers[*]}"
  return "$code"
}
PROMPT_COMMAND=__cours_contexte
