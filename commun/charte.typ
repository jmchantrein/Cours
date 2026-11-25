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
// Clés : en-têtes des rôles ; invite / invite-clair (schémas) ; appli ; cadres de terminal hote-t, invite-t, imbrique-t ;
// distant / distant-clair / distant-t : machine où l’on entre à distance (schéma, cadre de terminal) ;
// branche : commits d’une autre branche dans un graphe de commits (orange, opposé au bleu de main dans toutes les visions ;
// en achromatopsie, un orange clair : main (notion ou hote-t) est plus foncé, la branche plus claire).
// Écarts des couleurs ajoutées à leurs voisines (ΔE simulé, minimum sur les variantes) : branche/notion 48 et
// branche/hote-t (couverture) 18 (achromatopsie) ;
// distant/notion et invite 15 (achromatopsie), distant-clair/appli 17 (projection), invite-clair 11 (achromatopsie) ;
// distant-t/hote-t, invite-t, imbrique-t 32 dans les dichromasies, 9 en achromatopsie (le trait mixte du cadre double
// la clarté). Contrastes : texte sur branche ≥ 6,0 ; distant-t sur le fond nuit ≥ 4,5 ; distant sur distant-clair ≥ 4,6.
#let palette-projection = (
  notion: rgb("#1F63C9"), pratique: rgb("#1E7A46"), question: rgb("#9BCCA9"), reponse: rgb("#004D1D"), retenir: rgb("#14213D"),
  precaution: rgb("#F2C94C"), avertissement: rgb("#B4530F"), danger: rgb("#B3123C"),
  invite: rgb("#7B3FB0"), invite-clair: rgb("#DDC4F5"), appli: rgb("#D3E4FB"),
  hote-t: rgb("#7DB4FF"), invite-t: rgb("#C9A7F5"), imbrique-t: rgb("#FF9EC4"),
  distant: rgb("#0B6B64"), distant-clair: rgb("#C3EAE5"), distant-t: rgb("#5ED6C6"), branche: rgb("#E08A1E"),
)
// Dichromasies rouge-vert : seuls l’axe bleu/jaune et la clarté restent. Le vert passe au bleu-vert, le rouge
// s’assombrit, l’invité (violet, vu comme du bleu) devient ocre. Écart minimal entre rôles : 28 (deutéranopie),
// 23 (protanopie), contre 9 et 12 avec la palette de projection. Le distant (turquoise, confondu avec le vert) devient
// violet sombre, plus foncé que le bleu des notions.
#let rouge-vert = (pratique: rgb("#006E7A"), question: rgb("#9CC9D0"), reponse: rgb("#004955"), danger: rgb("#7A0F2A"), invite: rgb("#7A5A00"),
  invite-clair: rgb("#EEDC9A"), invite-t: rgb("#E8C95A"), imbrique-t: rgb("#E8E8E8"),
  distant: rgb("#3D0F6B"), distant-clair: rgb("#BFA8DE"), distant-t: rgb("#B47499"),
  // l’orange reste distinct du bleu de main : seul l’axe bleu/jaune compte
  branche: rgb("#E08A1E"))
#let palettes = (
  deuteranopie: rouge-vert,
  protanopie: rouge-vert,
  // Confusion bleu/vert et jaune/violet : le vert tire vers l’olive. Écart minimal : 18 → 28.
  tritanopie: (pratique: rgb("#6B6B00"), question: rgb("#C9C389"), reponse: rgb("#414300"), danger: rgb("#C2002F"), invite: rgb("#8E2C8C"),
    invite-clair: rgb("#F4C6E6"), invite-t: rgb("#F29ACB"), imbrique-t: rgb("#E9E39A"),
    // le distant (turquoise, confondu avec le bleu) devient rouge brique
    distant: rgb("#9E1C1C"), distant-clair: rgb("#F2B8A8"), distant-t: rgb("#E3573B"),
    // l’orange reste distinct du bleu de main (ΔE 84 contre la notion)
    branche: rgb("#E08A1E")),
  // Sans couleur : une échelle de clarté L* (en-têtes retenir 8, danger 18, notion 28, pratique 38,
  // avertissement 48 ; en-têtes clairs à texte foncé : réponse 60, question 74, précaution 90 ; cadres 58/76/91,
  // cadre distant 67 ; schémas : distant 13, distant-clair 67 ; branche 76, contre notion 28 et hote-t 58).
  achromatopsie: (retenir: rgb("#10172A"), danger: rgb("#620019"), notion: rgb("#1A4082"),
    avertissement: rgb("#A76034"), pratique: rgb("#2D6441"), question: rgb("#90C19E"), reponse: rgb("#729A7D"), precaution: rgb("#FFDF8A"),
    invite: rgb("#714793"), invite-clair: rgb("#CCBADC"), appli: rgb("#E0ECFC"),
    hote-t: rgb("#6C8DBF"), invite-t: rgb("#CAB1E8"), imbrique-t: rgb("#FFDAF4"),
    distant: rgb("#16203A"), distant-clair: rgb("#9FA3AA"), distant-t: rgb("#A3A3A3"), branche: rgb("#EDB06E")),
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
    // machine où l’on entre à distance (SSH) : turquoise ; commits d’une autre branche : orange.
    distant: pal.distant, distant-clair: pal.distant-clair, distant-t: pal.distant-t, branche: pal.branche,
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

// ---------- Illustrations de couverture ----------
// Partagées par les diapos et les pages web. c : les couleurs d’une variante ; u : l’unité de dessin
// (pour les diapos, 1 px de la maquette).
#let illustration(nom, c, u) = {
  let px(n) = n * u
  if nom == "vm" {
    // trois VM (invité) sur un hyperviseur (hôte) et le matériel
    stack(spacing: px(16),
      grid(columns: (px(176),) * 3, column-gutter: px(16),
        ..range(3).map(_ => box(width: px(176), height: px(96), fill: c.invite-t, radius: px(12)))),
      box(width: px(560), height: px(56), fill: c.hote-t, radius: px(12)),
      box(width: px(560), height: px(56), fill: c.gris, radius: px(12)),
    )
  } else if nom == "couches" {
    // couches d’image en lecture seule : un dégradé de bleus, du plus sombre (base) au plus clair ;
    // au sommet, la couche du conteneur en lecture/écriture, claire et bordée de tirets
    stack(spacing: px(14),
      box(width: px(560), height: px(56), radius: px(12), fill: c.hote-t.transparentize(80%),
        stroke: (paint: c.hote-t, thickness: px(3), dash: "dashed")),
      ..(70%, 45%, 20%).map(p => box(width: px(560), height: px(56), radius: px(12),
        fill: color.mix((c.hote-t, p), (c.nuit, 100% - p)))),
    )
  } else if nom == "tube" {
    // un tube : trois commandes reliées par des « | », lancées par le shell, sur le noyau
    stack(spacing: px(16),
      grid(columns: (px(136), px(76)) * 2 + (px(136),), align: horizon,
        ..range(5).map(i => if calc.even(i) { box(width: px(136), height: px(96), fill: c.hote-t, radius: px(12)) }
          else { box(width: px(76), height: px(16), fill: c.hote-t.transparentize(40%)) })),
      box(width: px(560), height: px(56), fill: color.mix((c.hote-t, 45%), (c.nuit, 55%)), radius: px(12)),
      box(width: px(560), height: px(56), fill: c.gris, radius: px(12)),
    )
  } else if nom == "graphe" {
    // un graphe de commits : main (bleu) et une branche (orange) qui s’en détache puis y revient
    let (r, bas, haut) = (28, 190, 60)
    let main = (40, 160, 280, 400, 520).map(x => (x, bas))
    let branche = ((220, haut), (340, haut))
    let lien(a, b) = place(top + left, line(start: (px(a.at(0)), px(a.at(1))), end: (px(b.at(0)), px(b.at(1))),
      stroke: px(6) + c.hote-t.transparentize(30%)))
    box(width: px(560), height: px(250), {
      for i in range(4) { lien(main.at(i), main.at(i + 1)) }
      lien(main.at(1), branche.at(0)); lien(branche.at(0), branche.at(1)); lien(branche.at(1), main.at(3))
      for (p, f) in main.map(p => (p, c.hote-t)) + branche.map(p => (p, c.branche)) {
        place(top + left, dx: px(p.at(0) - r), dy: px(p.at(1) - r), circle(radius: px(r), fill: f))
      }
    })
  } else if nom == "texte" {
    // un fichier texte structuré : des clés (bleu) et leurs valeurs, indentées, et le curseur de l’éditeur
    let lignes = ((0, 150, 0), (1, 110, 190), (1, 130, 150), (2, 90, 200), (2, 120, 120), (1, 100, 0), (0, 140, 170))
    box(width: px(560), stroke: px(3) + c.hote-t, radius: px(12), inset: px(28), stack(spacing: px(16),
      ..lignes.enumerate().map(((i, (n, cle, val))) => {
        h(px(48 * n))
        box(width: px(cle), height: px(18), radius: px(9), fill: c.hote-t)
        if val > 0 { h(px(16)); box(width: px(val), height: px(18), radius: px(9), fill: color.mix((c.hote-t, 45%), (c.nuit, 55%))) }
        if i == lignes.len() - 1 { h(px(12)); box(width: px(14), height: px(28), fill: c.fond) }
      })))
  } else if nom == "tunnel" {
    // le poste (hôte) relié à une machine distante par un tunnel chiffré, à travers le réseau (gris) ;
    // la machine distante a le trait mixte des cadres de terminal : sans couleur, elle se distingue du poste par le trait
    stack(spacing: px(16),
      grid(columns: (px(176), px(208), px(176)), align: horizon,
        box(width: px(176), height: px(160), fill: c.hote-t, radius: px(12)),
        box(width: px(208), height: px(56), fill: c.distant-t.transparentize(80%),
          stroke: (y: (paint: c.distant-t, thickness: px(3), dash: "dashed")),
          align(center + horizon, box(width: px(56), height: px(20), radius: px(10), fill: c.distant-t))),
        box(width: px(176), height: px(160), fill: c.distant-t.transparentize(70%), radius: px(12),
          stroke: (paint: c.distant-t, thickness: px(5), dash: "dash-dotted")),
      ),
      box(width: px(560), height: px(56), fill: c.gris, radius: px(12)),
    )
  } else if nom == "noeuds" {
    // un nœud de contrôle (hôte) et ses tâches, relié à trois nœuds gérés (distants)
    let noeuds = (0, 92, 184)
    box(width: px(560), height: px(248), {
      for y in noeuds {
        place(top + left, line(start: (px(176), px(124)), end: (px(384), px(y + 32)), stroke: px(5) + c.gris))
      }
      place(top + left, box(width: px(176), height: px(248), fill: c.hote-t, radius: px(12), inset: px(24),
        stack(spacing: px(16), ..(128, 96, 112, 80).map(l => box(width: px(l), height: px(16), radius: px(8),
          fill: color.mix((c.hote-t, 45%), (c.nuit, 55%)))))))
      for y in noeuds {
        place(top + left, dx: px(384), dy: px(y), box(width: px(176), height: px(64), radius: px(12),
          fill: c.distant-t.transparentize(70%), stroke: (paint: c.distant-t, thickness: px(5), dash: "dash-dotted")))
      }
    })
  } else { panic("illustration inconnue : " + nom) }
}
