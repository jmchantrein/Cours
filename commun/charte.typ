// charte.typ — ce que tous les supports partagent : rôles pédagogiques, palettes des variantes, couleurs.
// Les diapos (theme-cours.typ) et les pages web des TP (theme-tp.typ) en dérivent leur mise en forme.

// ---------- Rôles pédagogiques ----------
// Le cours dit ce qu’est un bloc (son rôle) ; la charte décide de son apparence.
#let roles-def = (
  notion: (nom: "Notion", projection: "bleu", sens: "définir, expliquer"),
  retenir: (nom: "À retenir", projection: "bleu nuit", sens: "synthèse, point clé"),
  pratique: (nom: "Pratique", projection: "vert", sens: "exemple, démonstration, usage réel"),
  question: (nom: "Question", projection: "vert clair", sens: "exercice : ce qu’on demande de faire"),
  reponse: (nom: "Réponse", projection: "vert foncé", sens: "corrigé d’une question"),
  precaution: (nom: "Précaution", projection: "jaune", sens: "nuance, confusion fréquente, limite"),
  avertissement: (nom: "Avertissement", projection: "orange", sens: "erreur probable, mauvaise pratique"),
  danger: (nom: "Danger", projection: "rouge", sens: "risque réel : sécurité, perte de données"),
)

// ---------- Variantes de rendu ----------
// Choisies à la compilation : typst compile --input variante=<nom> …
// - projection (défaut) : rendu de projection, pensé pour la vision typique ;
// - deuteranopie, protanopie, tritanopie, achromatopsie : palette propre à chaque vision ;
// - dyslexie : lettres, mots et lignes plus espacés, ni capitales forcées ni italique.
// Chaque palette garde les rôles distincts pour la vision visée (écarts ΔE CIELAB simulés : Machado 2009
// pour les dichromasies, clarté seule pour l’achromatopsie) ; les pictogrammes doublent la couleur partout.
// Contraste du texte d’en-tête (blanc ou encre, choisi selon la clarté) et du texte sur terminal : ≥ 4,5.
// Clés : en-têtes des rôles ; invite / invite-clair (schémas) ; appli ; cadres de terminal hote-t, invite-t, imbrique-t.
#let palette-projection = (
  notion: rgb("#1F63C9"), pratique: rgb("#1E7A46"), question: rgb("#9BCCA9"), reponse: rgb("#004D1D"), retenir: rgb("#14213D"),
  precaution: rgb("#F2C94C"), avertissement: rgb("#B4530F"), danger: rgb("#B3123C"),
  invite: rgb("#7B3FB0"), invite-clair: rgb("#DDC4F5"), appli: rgb("#D3E4FB"),
  hote-t: rgb("#7DB4FF"), invite-t: rgb("#C9A7F5"), imbrique-t: rgb("#FF9EC4"),
)
// Dichromasies rouge-vert : seuls l’axe bleu/jaune et la clarté restent. Le vert passe au bleu-vert, le rouge
// s’assombrit, l’invité (violet, vu comme du bleu) devient ocre. Écart minimal entre rôles : 28 (deutéranopie),
// 23 (protanopie), contre 9 et 12 avec la palette de projection.
#let rouge-vert = (pratique: rgb("#006E7A"), question: rgb("#9CC9D0"), reponse: rgb("#004955"), danger: rgb("#7A0F2A"), invite: rgb("#7A5A00"),
  invite-clair: rgb("#EEDC9A"), invite-t: rgb("#E8C95A"), imbrique-t: rgb("#E8E8E8"))
#let palettes = (
  deuteranopie: rouge-vert,
  protanopie: rouge-vert,
  // Confusion bleu/vert et jaune/violet : le vert tire vers l’olive. Écart minimal : 18 → 28.
  tritanopie: (pratique: rgb("#6B6B00"), question: rgb("#C9C389"), reponse: rgb("#414300"), danger: rgb("#C2002F"), invite: rgb("#8E2C8C"),
    invite-clair: rgb("#F4C6E6"), invite-t: rgb("#F29ACB"), imbrique-t: rgb("#E9E39A")),
  // Sans couleur : une échelle de clarté L* (en-têtes retenir 8, danger 18, notion 28, pratique 38,
  // avertissement 48 ; en-têtes clairs à texte foncé : réponse 60, question 74, précaution 90 ; cadres 58/76/91).
  achromatopsie: (retenir: rgb("#10172A"), danger: rgb("#620019"), notion: rgb("#1A4082"),
    avertissement: rgb("#A76034"), pratique: rgb("#2D6441"), question: rgb("#90C19E"), reponse: rgb("#729A7D"), precaution: rgb("#FFDF8A"),
    invite: rgb("#714793"), invite-clair: rgb("#CCBADC"), appli: rgb("#E0ECFC"),
    hote-t: rgb("#6C8DBF"), invite-t: rgb("#CAB1E8"), imbrique-t: rgb("#FFDAF4")),
)
#let variantes = ("projection", "dyslexie") + palettes.keys()
#let variante = sys.inputs.at("variante", default: "projection")
#assert(variante in variantes,
  message: "variante inconnue : " + variante + " (attendu : " + variantes.join(", ") + ")")
#let dys = variante == "dyslexie"

// Texte lisible sur une couleur : encre sur fond clair, blanc cassé sur fond foncé.
#let encre = rgb("#14213D")
#let fond = rgb("#F6F7F3")
#let clarte(col) = {
  let (r, g, b, ..) = col.rgb().components()
  let lin(x) = { let v = x / 100%; if v <= 0.04045 { v / 12.92 } else { calc.pow((v + 0.055) / 1.055, 2.4) } }
  0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}
#let texte-sur(col) = if clarte(col) > 0.3 { encre } else { fond }

// Fonds clairs des rôles en projection (choisis à la main) ; dans les variantes, dérivés de l’en-tête.
#let fonds-projection = (
  notion: rgb("#E8EFFA"), pratique: rgb("#E4F2E9"), question: rgb("#F0F8F2"), reponse: rgb("#DDEBE1"), retenir: rgb("#E6E9F0"),
  precaution: rgb("#FFF6D9"), avertissement: rgb("#FBE9DA"), danger: rgb("#FBE3E8"),
)

// Couleurs (c) et rôles (roles) d’une variante. Les supports compilés pour une variante (diapos) lisent
// `c` et `roles` ci-dessous ; ceux qui embarquent toutes les variantes (pages web des TP) appellent charte-de.
#let charte-de(v) = {
  let pal = palette-projection + palettes.at(v, default: (:))
  let c = (
    nuit: rgb("#0F1E33"), encre: encre, gris: rgb("#5B6680"),
    ardoise: rgb("#44506A"), fond: fond, espace: rgb("#EDF0F3"),
    filet: rgb("#D5DAE0"), prompt: rgb("#7DB4FF"), commentaire: rgb("#9FB0C8"), texte-term: rgb("#E6EDF7"),
    encart: rgb("#2A3954"),
    // Accent de la charte (surtitres, code, numéros) : la couleur des notions.
    bleu: pal.notion, bleu-clair: rgb("#E8EFFA"),
    // Structure des schémas : hôte et applications en bleu, invité (VM, OS invité) en violet.
    appli: pal.appli, invite: pal.invite, invite-clair: pal.invite-clair,
    hote-t: pal.hote-t, invite-t: pal.invite-t, imbrique-t: pal.imbrique-t,
  )
  let roles = roles-def.keys().map(r => {
    let entete = pal.at(r)
    let fond-role = if v in palettes { color.mix((entete, 14%), (fond, 86%)) } else { fonds-projection.at(r) }
    // accent : texte coloré sur le fond clair du rôle (le jaune, trop clair, est assombri)
    let accent = if clarte(entete) > 0.3 { entete.darken(60%) } else { entete }
    (r, (entete: entete, fond: fond-role, texte: texte-sur(entete), accent: accent))
  }).to-dict()
  (pal: pal, c: c, roles: roles)
}
#let (pal, c, roles) = charte-de(variante)

#let mono = "IBM Plex Mono"
