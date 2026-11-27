// theme-cours.typ — charte commune des cours (virtualisation, Docker…) pour Touying.
// Reprend les couleurs, polices et proportions du deck HTML (maquette 1920 × 1080 px).

#import "@preview/touying:0.8.0": *
#import themes.simple: *

// Rôles, variantes, palettes et couleurs : charte.typ, commune aux diapos et aux TP.
#import "charte.typ": *

// Échelle : 1 px de la maquette = 0,4385 pt sur la page 16:9 de Touying.
#let px(n) = n * 0.4385pt
// Capitales décoratives (surtitres, étiquettes), gardées en casse normale pour la variante dyslexie.
#let maj(x) = if dys { x } else { upper(x) }

// Pictogramme d’un rôle : cerveau pour « à retenir », coureur en sueur pour pratique, question et réponse
// (dessins Tabler Icons, MIT, dans pictos/), triangle « ! » pour les trois niveaux d’alerte ; rien pour une notion.
// Dans les variantes seulement, le triangle est suivi d’un feu tricolore (précaution : feu du bas,
// avertissement : milieu, danger : haut) qui porte le niveau par la position, sans la couleur.
// Les dessins au trait paraissent plus petits qu’une forme pleine : on les agrandit d’un quart.
#let icone(fichier, couleur, t) = box(width: t * 1.25, height: t * 1.25, baseline: 24%,
  image(bytes(read(fichier).replace("currentColor", couleur.to-hex())), format: "svg", width: t * 1.25, height: t * 1.25))
#let picto(role, forme, glyphe, t: px(30)) = {
  if role == "retenir" { return icone("pictos/cerveau.svg", forme, t) }
  // le coureur signale un effort des étudiants : seulement sur les questions (« À vous »)
  if role == "question" { return icone("pictos/coureur.svg", forme, t) }
  let niveaux = ("danger", "avertissement", "precaution")  // de haut en bas
  if role not in niveaux { return none }
  let triangle = box(width: t, height: t, baseline: 18%, {
    polygon(fill: forme, (t * 0.5, 0pt), (t, t * 0.95), (0pt, t * 0.95))
    place(top + left, dy: t * 0.2, box(width: t, height: t * 0.8,
      align(center + horizon, text(size: t * 0.62, weight: 700, fill: glyphe, top-edge: "cap-height", bottom-edge: "baseline", "!"))))
  })
  let d = t * 0.27
  let feu = box(baseline: 18%, height: t, stroke: t * 0.06 + forme, radius: t * 0.2,
    inset: (x: t * 0.07, y: t * 0.04),
    stack(spacing: t * 0.04, ..niveaux.map(n => circle(radius: d / 2,
      fill: if n == role { forme } else { none }, stroke: t * 0.05 + forme))))
  if variante == "projection" { return triangle }
  triangle; h(t * 0.15); feu
}


// ---------- Thème ----------
#let cours-theme(auteur: none, titre-court: none, body) = {
  show: simple-theme.with(
    aspect-ratio: "16-9",
    header: none,
    header-right: none,
    footer: grid(
      columns: (1fr, auto, 1fr),
      text(size: px(22), fill: c.gris, auteur),
      text(size: px(22), fill: c.gris, titre-court),
      align(right, text(size: px(22), fill: c.gris,
        context [#utils.slide-counter.display()/#utils.last-slide-number])),
    ),
    footer-right: none,
    primary: c.bleu,
    // Chaque diapo : surtitre = section (titre `=`), titre = diapo (titre `==`).
    subslide-preamble: block(below: px(36), {
      text(size: px(24), weight: 600, tracking: px(2), fill: c.bleu,
        maj(utils.display-current-heading(level: 1)))
      v(px(16), weak: true)
      text(size: px(64), weight: 600, utils.display-current-heading(level: 2))
    }),
    config-common(new-section-slide-fn: none, show-strong-with-alert: false),
    config-page(fill: c.fond, margin: (x: px(128), top: px(120), bottom: px(150)), footer-descent: px(62)),
  )
  // Boîtes de ligne comme en CSS (ascendante → descendante) : mêmes hauteurs de blocs que le deck HTML.
  set text(font: "IBM Plex Sans", size: px(28), fill: c.encre, lang: "fr",
    top-edge: "ascender", bottom-edge: "descender")
  set par(leading: 0.38em)
  // Dyslexie : espacements augmentés (le code garde ses colonnes), pas d’italique.
  set text(tracking: 0.04em, spacing: 130%) if dys
  set par(leading: 0.6em) if dys
  show raw: set text(tracking: 0pt, spacing: 100%) if dys
  show raw.where(block: true): set par(leading: 0.38em) if dys
  show emph: it => if dys { it.body } else { it }
  show strong: it => text(weight: 600, it.body)  // gras sans recoloration
  show raw: set text(font: mono)
  // Typst réduit déjà le code à 0,8 em : 1,15 em donne environ 0,92 de la taille du texte.
  show raw.where(block: false): set text(size: 1.15em, fill: c.bleu)
  show raw.where(block: true): set text(size: px(20))
  body
}

// ---------- Rangées de même hauteur ----------
// Chaque cellule est une fonction hauteur => contenu ; toutes prennent la hauteur de la plus haute
// (équivalent du « align-items: stretch » du deck HTML).
#let rangee(gouttiere: px(32), poids: auto, ..cellules) = layout(taille => {
  let cs = cellules.pos()
  let p = if poids == auto { (1,) * cs.len() } else { poids }
  let utile = taille.width - gouttiere * (cs.len() - 1)
  let largeurs = p.map(x => utile * x / p.sum())
  let h = calc.max(..cs.zip(largeurs).map(((f, l)) => std.measure(block(width: l, f(auto))).height))
  grid(columns: largeurs, column-gutter: gouttiere, ..cs.map(f => f(h)))
})

// ---------- Blocs colorés ----------
// bloc(...) décrit un bloc ; colonnes(...) les pose côte à côte, à hauteur égale.
// role : notion (défaut), pratique, retenir, precaution, avertissement, danger (voir roles-def).
#let bloc(titre, role: "notion", poids: 1, taille: px(28), taille-titre: px(28), corps) = {
  assert(role in roles, message: "rôle inconnu : " + role + " (attendu : " + roles.keys().join(", ") + ")")
  (titre: titre, role: role, poids: poids, taille: taille, taille-titre: taille-titre, corps: corps)
}

// En-tête d’un rôle : pictogramme puis titre.
#let entete-role(role, titre, taille) = {
  let r = roles.at(role)
  let p = picto(role, r.texte, r.entete, t: taille * 1.05)
  // le code d'un titre prend la couleur du titre (sinon : code bleu sur en-tête bleu)
  show raw: set text(fill: r.texte)
  text(fill: r.texte, size: taille, weight: 600, { if p != none { p; h(taille * 0.4) }; titre })
}

#let rendre-bloc(b, hauteur: auto) = block(
  width: 100%, height: hauteur, radius: px(12), clip: true, fill: roles.at(b.role).fond,
  stack(
    block(width: 100%, fill: roles.at(b.role).entete, inset: (x: px(28), y: px(12)),
      entete-role(b.role, b.titre, b.taille-titre)),
    block(width: 100%, inset: (x: px(28), y: px(22)), { set text(size: b.taille); b.corps }),
  ),
)

#let colonnes(gouttiere: px(32), ..blocs) = rangee(gouttiere: gouttiere,
  poids: blocs.pos().map(b => b.poids),
  ..blocs.pos().map(b => h => rendre-bloc(b, hauteur: h)))

#let espace = v(px(24))

// Bandeau sombre (origine, éditeur, version…).
#let bandeau(taille: px(25), corps) = block(width: 100%, fill: c.nuit, radius: px(12),
  inset: (x: px(28), y: px(16)), {
    set text(size: taille, fill: c.texte-term)
    show raw.where(block: false): set text(fill: c.prompt)
    corps
  })

// Touche du clavier, dans le texte : #touche[Échap], #touche[Ctrl+b].
#let touche(t) = box(stroke: px(2) + c.gris, radius: px(6), inset: (x: px(7), y: px(1)), outset: (y: px(3)),
  fill: c.fond, text(font: mono, size: 0.85em, weight: 600, fill: c.encre, tracking: 0pt, t))

// Tableau à en-tête, lignes alternées. Les cellules se donnent ligne par ligne, ou à plat ; les réglages nommés
// (inset, align) passent à table. taille : taille du texte, sinon celle du bloc qui le contient.
// Les fonds sont translucides : ils se lisent sur le fond de la diapo comme sur celui de n’importe quel bloc.
#let tableau(colonnes, taille: none, entete, ..lignes) = {
  set text(size: taille) if taille != none
  table(columns: colonnes, stroke: none, ..((inset: (x: px(10), y: px(6))) + lignes.named()),
    fill: (x, y) => if y == 0 { c.bleu.transparentize(82%) } else if calc.even(y) { c.bleu.transparentize(93%) },
    table.header(..entete.map(t => text(weight: 600, t))),
    ..lignes.pos().flatten())
}

// Petite note sur le fond clair d’un rôle, avec son pictogramme.
#let note(role: "pratique", taille: px(20), corps) = {
  let r = roles.at(role)
  let p = picto(role, r.accent, r.fond, t: taille * 1.05)
  block(width: 100%, fill: r.fond, radius: px(10), inset: (x: px(18), y: px(12)),
    text(size: taille, fill: c.encre, { if p != none { p; h(taille * 0.4) }; corps }))
}

// Encadré pleine hauteur sur le fond clair d’un rôle, à libellé en tête (« En vrai : », « Intérêt : »…).
#let encadre(role: "notion", libelle: none, taille: px(22), hauteur: auto, corps) = {
  let r = roles.at(role)
  let p = picto(role, r.accent, r.fond, t: taille * 1.05)
  block(width: 100%, height: hauteur, fill: r.fond, radius: px(12), inset: (x: px(20), y: px(12)),
    align(horizon, text(size: taille, {
      if p != none { p; h(taille * 0.4) }
      if libelle != none { text(weight: 600, fill: r.accent, libelle); " " }
      corps
    })))
}

// ---------- Terminal ----------
// Lignes « $ … » : invite colorée ; lignes « # … » : commentaire grisé.
#let terminal(titre: "Terminal", taille: px(20), hauteur: auto, corps) = block(
  width: 100%, height: hauteur, fill: c.nuit, radius: px(12), inset: (x: px(22), y: px(14)), {
    set text(fill: c.texte-term)
    show raw.where(block: true): set text(size: taille)
    show raw.where(block: true): set block(above: px(4), below: px(4))
    show raw.line: l => {
      let t = l.text
      if t.starts-with("$ ") { text(fill: c.prompt)[\$]; " " + t.slice(2) }
      else if t.starts-with("# ") { text(fill: c.commentaire, t) }
      else { t }
    }
    if titre != none {
      block(below: px(8), text(size: px(24), weight: 600, tracking: px(2), fill: c.prompt, maj(titre)))
    }
    corps
  },
)

// Fichier affiché (un objet), à distinguer du terminal (des commandes) : fond clair, nom du fichier en tête
// (none : sans nom), contenu brut. #fichier([config.yaml])[```yaml …```] ; à côté d’un terminal, dans une rangee.
#let fichier(nom, taille: px(20), hauteur: auto, corps) = block(width: 100%, height: hauteur,
  fill: c.espace, stroke: px(1) + c.filet, radius: px(12), clip: true, stack(
    if nom != none { block(width: 100%, fill: c.filet, inset: (x: px(18), y: px(6)),
      text(font: mono, size: px(20), weight: 600, fill: c.ardoise, nom)) },
    block(width: 100%, inset: (x: px(18), y: px(10)), {
      show raw.where(block: true): set text(size: taille)
      corps
    }),
  ))

// Encart plus clair dans un terminal (moniteur QEMU, session dans l'invité…).
#let encart(titre, corps) = block(width: 100%, fill: c.encart, radius: px(8),
  inset: (x: px(14), y: px(10)), above: px(10), below: px(4), {
    block(below: px(6), text(font: mono, size: px(22), weight: 600, fill: c.invite-t, maj(titre)))
    corps
  })

// Cadre dans un terminal : une machine lancée par la commande au-dessus, ou dans laquelle elle entre.
// niveau 0 = hôte (bleu, trait plein), 1 = VM invitée (violet, tirets), 2 = VM imbriquée (rose, pointillés),
// "distant" = session sur une machine distante, ouverte par ssh (turquoise, trait mixte) : le trait double la couleur.
#let cadre(etiquette, niveau: 0, corps) = {
  let (couleur, trait) = if niveau == "distant" { (c.distant-t, "dash-dotted") } else {
    ((c.hote-t, c.invite-t, c.imbrique-t).at(niveau), ("solid", "dashed", "dotted").at(niveau)) }
  block(
    width: 100%, stroke: (paint: couleur, thickness: px(2), dash: trait), radius: px(10),
    fill: couleur.transparentize(90%),
    inset: (x: px(12), top: px(6), bottom: px(8)), above: px(8), below: px(4), {
      block(below: px(6), text(size: px(18), weight: 600, tracking: px(1), fill: couleur, maj(etiquette)))
      corps
    },
  )
}

// ---------- Listes à deux colonnes (chronologie, fiches) ----------
// Avec uncover (diapo animée), la ligne i apparaît au clic debut + i.
#let lignes(largeur: px(260), taille-cle: px(36), taille: px(30), uncover: none, debut: 1, ..paires) = {
  let ps = paires.pos()
  let montre(i, x) = if uncover == none { x } else { uncover(str(debut + i) + "-", x) }
  grid(columns: (largeur, 1fr), align: horizon,
    inset: (x, y) => (y: px(12), left: if x == 1 { px(40) } else { 0pt }),
    stroke: (x, y) => if y < ps.len() - 1 { (bottom: px(1) + c.filet) },
    ..ps.enumerate().map(((i, (k, v))) => (montre(i, text(size: taille-cle, weight: 600, fill: c.bleu, k)),
      montre(i, text(size: taille, v)))).flatten())
}

// Plan du cours : titre de partie, description ; sans numéro ni puce (un sommaire n’en a pas besoin).
#let plan-cours(uncover: none, ..parties) = {
  let ps = parties.pos()
  let montre(i, x) = if uncover == none { x } else { uncover(str(i + 1) + "-", x) }
  grid(columns: (1fr,), align: horizon,
    inset: (y: px(16)),
    stroke: (x, y) => if y < ps.len() - 1 { (bottom: px(1) + c.filet) },
    ..ps.enumerate().map(((i, (t, d))) => (
      montre(i, { text(size: px(40), weight: 600, t); linebreak(); text(size: px(32), fill: c.ardoise, d) }),
    )).flatten())
}

// ---------- Corrigé de TP ----------
// La question porte le vert clair du rôle « question » ; la réponse, une barre vert foncé.
#let question(n, corps) = grid(columns: (auto, 1fr), column-gutter: px(12),
  box(fill: roles.question.entete, radius: px(6), inset: (x: px(10), y: px(2)),
    text(size: px(22), weight: 600, fill: roles.question.texte, str(n))),
  text(size: px(26), fill: c.ardoise, corps))
#let reponse(corps) = block(width: 100%, stroke: (left: px(8) + roles.reponse.entete), inset: (left: px(16)), corps)

#let filet-corrige = line(length: 100%, stroke: px(2) + rgb("#C9D6EA"))

// La réponse s’écrit reponse(...) dans le cours, à l’intérieur de son uncover : la barre apparaît avec elle.
#let corrige(n, q, rep) = grid(columns: (px(700), 1fr), column-gutter: px(32),
  question(n, q), rep)

// Plusieurs questions et leurs réponses sur une diapo : la question reste visible, chaque réponse apparaît
// à son clic. items : (n, [question], reponse[…]) ; la réponse s’écrit avec reponse(…).
#let corriges(note: none, contexte: none, ..items) = {
  let qa = items.pos()
  slide(repeat: qa.len() + 1, self => {
    let (uncover,) = utils.methods(self)
    if contexte != none { place(top + left, dy: -px(104), block(width: 100%, contexte)) }
    for (i, it) in qa.enumerate() {
      corrige(it.at(0), it.at(1), uncover(str(i + 2) + "-", it.at(2)))
      if i < qa.len() - 1 { v(px(16)) }
    }
    if note != none { utils.speaker-note(self: self, note) }
  })
}

// ---------- Schémas en couches ----------
#let couche(texte, fond: c.nuit, hauteur: px(72), taille: px(30), puces: ()) = block(
  width: 100%, height: hauteur, fill: fond, radius: px(8),
  align(center + horizon, stack(spacing: px(8),
    text(fill: c.fond, size: taille, weight: 600, texte),
    if puces.len() > 0 {
      puces.map(p => box(fill: c.bleu, radius: px(8), inset: (x: px(12), y: px(4)),
        text(fill: c.fond, size: px(24), weight: 600, p))).join(h(px(10)))
    },
  )),
)

#let vm(nom, haut: "Appli", bas: "OS invité", couleur: c.invite, fond-bas: c.invite-clair, case: px(80),
  taille: px(28)) = block(
  width: 100%, stroke: px(3) + couleur, radius: px(12), inset: px(8), fill: c.fond,
  stack(spacing: px(8),
    align(center, text(fill: couleur, size: px(24), weight: 600, nom)),
    block(width: 100%, height: case, fill: c.appli, radius: px(8),
      align(center + horizon, text(size: taille, weight: 600, haut))),
    block(width: 100%, height: case, fill: fond-bas, radius: px(8),
      align(center + horizon, text(size: taille, weight: 600, bas))),
  ),
)

// Pile complète : titre, espace utilisateur (gestion + VM/conteneurs), noyau ou hyperviseur, matériel.
#let pile-archi(titre, espace, gestion, cases, noyau, puces, materiel) = stack(spacing: px(8),
  text(size: px(40), weight: 600, titre),
  v(px(8)),
  block(width: 100%, fill: c.espace, radius: px(12), inset: (x: px(12), top: px(12), bottom: px(20)),
    stack(spacing: px(8),
      text(size: px(24), weight: 600, fill: c.gris, espace),
      block(width: 100%, stroke: (paint: c.gris, thickness: px(2), dash: "dashed"), radius: px(10),
        inset: (x: px(12), y: px(8)), align(center, text(size: px(24), fill: c.ardoise, gestion))),
      grid(columns: (1fr,) * cases.len(), column-gutter: px(12), ..cases),
    )),
  couche(noyau, hauteur: px(108), taille: px(28), puces: puces),
  couche(materiel, fond: c.ardoise, hauteur: px(80), taille: px(32)),
)

// Élément placé sur un canevas aux coordonnées de la maquette (px).
#let pose(x, y, corps) = place(top + left, dx: px(x), dy: px(y), corps)
// Flèche sur un canevas, de (x1, y1) à la pointe (x2, y2), en px de la maquette, dans toute direction.
// motif : autre motif de trait ("dotted", "dash-dotted"…), prioritaire sur tirets ; pointe : false, un simple trait.
#let fleche-pose(x1, y1, x2, y2, couleur: c.ardoise, ep: 4, tirets: false, motif: none, pointe: true) = {
  let (dx, dy) = (x2 - x1, y2 - y1)
  let l = calc.max(calc.sqrt(dx * dx + dy * dy), 0.001)
  let (ux, uy) = (dx / l, dy / l)
  let p = if pointe { calc.max(18, 14 + ep) } else { 0 }  // longueur de la pointe : 18, plus au-delà d’un trait de 4
  let (bx, by) = (x2 - ux * p, y2 - uy * p)  // base de la pointe
  let (nx, ny) = (-uy * p * 10 / 18, ux * p * 10 / 18)
  let dash = if motif != none { motif } else if tirets { "dashed" } else { none }
  let trait = if dash != none { (paint: couleur, thickness: px(ep), dash: dash) } else { px(ep) + couleur }
  if not pointe { place(top + left, line(start: (px(x1), px(y1)), end: (px(x2), px(y2)), stroke: trait)); return }
  place(top + left, line(start: (px(x1), px(y1)), end: (px(bx), px(by)), stroke: trait))
  place(top + left, polygon(fill: couleur, (px(x2), px(y2)), (px(bx + nx), px(by + ny)), (px(bx - nx), px(by - ny))))
}

// Canevas : hauteur fixe, éléments posés par pose(…) et fleche-pose(…) en coordonnées de la maquette.
#let canevas(hauteur, corps) = block(width: 100%, height: px(hauteur), corps)

// Machine d’un schéma : le poste (`distant: false`, bleu) ou une machine où l’on entre à distance (turquoise), comme les
// cadres de terminal. role : précision sous le nom ; le reste (puces, fichiers…) se place sous le nom, à la suite.
// #machine(distant: false, role: [poste d’Ada])[client] ; #machine([serveur], [#puce[sshd] #puce[python3]]).
#let machine(nom, role: none, distant: true, taille: px(28), ..contenu) = {
  let couleur = if distant { c.distant } else { c.bleu }
  block(width: 100%, fill: if distant { c.distant-clair } else { c.appli }, stroke: px(3) + couleur,
    radius: px(12), inset: (x: px(12), y: px(10)), {
      align(center, {
        text(size: taille, weight: 600, fill: couleur, nom)
        if role != none { linebreak(); text(size: px(20), fill: c.encre, role) }
      })
      if contenu.pos().len() > 0 { v(px(10)); align(center, contenu.pos().join(h(px(8)))) }
    })
}

// Flèche horizontale dans une grille (largeur de sa cellule), avec un libellé au-dessus et au-dessous.
// vers : "droite" (défaut) ou "gauche". Hors grille, sur un canevas : fleche-pose.
#let fleche(haut: none, bas: none, vers: "droite", couleur: c.gris, taille: px(20)) = {
  let trait = layout(t => box(width: t.width, height: px(18), {
    if vers == "droite" {
      place(left + horizon, line(length: t.width - px(14), stroke: px(3) + couleur))
      place(right + horizon, polygon(fill: couleur, (0pt, 0pt), (px(18), px(9)), (0pt, px(18))))
    } else {
      place(right + horizon, line(length: t.width - px(14), stroke: px(3) + couleur))
      place(left + horizon, polygon(fill: couleur, (px(18), 0pt), (0pt, px(9)), (px(18), px(18))))
    }
  }))
  stack(spacing: px(6),
    ..(
      if haut != none { align(center, text(size: taille, fill: couleur, haut)) },
      trait,
      if bas != none { align(center, text(size: taille, fill: couleur, bas)) },
    ).filter(x => x != none))
}

// ---------- Couverture ----------
// Illustrations de couverture (dessinées dans charte.typ) : « vm » (trois VM sur un hyperviseur, sur le matériel),
// « couches » (les couches d’une image : trois en lecture seule, une en lecture/écriture au sommet),
// « tube » (une invite de shell, puis des lignes de texte filtrées par deux tubes « | »), « graphe » (main et une branche fusionnée),
// « texte » (un fichier structuré, indenté, et le curseur), « tunnel » (le poste et une machine distante, reliés par
// un tunnel chiffré à travers le réseau), « noeuds » (un nœud de contrôle et trois nœuds gérés).
// (Nommée ici, car le paramètre `illustration` de page-titre masque la fonction de la charte.)
#let illustration-couverture(nom) = illustration(nom, c, px(1))

#let page-titre(titre, sous-titre, auteur, date, surtitre: "Cours · LERIA", illustration: "vm") = touying-slide-wrapper(self => {
  self = utils.merge-dicts(self,
    config-common(subslide-preamble: none),
    config-page(fill: c.nuit, footer: none, margin: px(128)))
  touying-slide(self: self, {
    place(top + left, dx: px(1104), dy: px(184), illustration-couverture(illustration))
    text(size: px(24), weight: 600, tracking: px(2), fill: c.prompt, maj(surtitre))
    v(1fr)
    block(width: px(1040), {
      // un titre trop long pour sa place (1040 px) est réduit pour ne pas chevaucher l'illustration
      context {
        let w = measure(text(size: px(144), weight: 600, titre)).width
        let k = calc.min(1, px(1040) / w)
        text(size: px(144) * k, weight: 600, fill: c.fond, titre)
      }
      v(px(32), weak: true)
      text(size: px(64), fill: rgb("#C3D0E4"), sous-titre)
    })
    v(1fr)
    text(size: px(40), weight: 600, fill: c.fond, auteur)
    v(px(8), weak: true)
    text(size: px(32), fill: rgb("#C3D0E4"), date)
  })
})

// ---------- Légende (variantes seulement) ----------
// Relie ce rendu à la projection : quand l’enseignant dit « le bloc orange », c’est le bloc avertissement.
// Hors numérotation, pour que les numéros de diapo restent ceux de la projection.
#let legende = touying-slide-wrapper(self => {
  self = utils.merge-dicts(self, config-common(subslide-preamble: none, freeze-slide-counter: true))
  touying-slide(self: self, {
    text(size: px(24), weight: 600, tracking: px(2), fill: c.bleu, maj("Légende · rendu " + variante))
    v(px(12), weak: true)
    text(size: px(52), weight: 600)[Lire les couleurs de ce rendu]
    v(px(16))
    grid(columns: (1fr, 1fr), column-gutter: px(32), row-gutter: px(14),
      ..roles-def.pairs().map(((r, d)) => block(width: 100%, radius: px(12), clip: true, fill: roles.at(r).fond, stack(
        block(width: 100%, fill: roles.at(r).entete, inset: (x: px(24), y: px(8)), entete-role(r, d.nom, px(26))),
        block(width: 100%, inset: (x: px(24), y: px(8)), text(size: px(22))[
          #d.sens. En projection : *#d.projection*.]),
      ))))
    v(px(16))
    grid(columns: (1fr,) * 4, column-gutter: px(24),
      ..((0, [Hôte], [bleu, trait plein]), (1, [VM invitée], [violet, tirets]), (2, [VM imbriquée], [rose, pointillés]),
        ("distant", [Session distante], [turquoise, trait mixte]))
        .map(((n, nom, proj)) => block(width: 100%, fill: c.nuit, radius: px(12), inset: px(12),
          cadre([#nom], niveau: n)[#text(size: px(20), fill: c.texte-term)[En projection : #proj]])))
  })
})

#let couverture(..args) = {
  page-titre(..args)
  if variante != "projection" { legende }
}

// Page de clôture, dans le même design que la couverture :
// #cloture(illustration: …)[Merci][Des questions ?][auteur][contact ou lien]
#let cloture(..args) = page-titre(..args)

// ---------- Contexte d’une commande ----------
// Où l’on est quand la commande s’exécute : compte (et machine), répertoire courant dans l’arborescence, ce qu’il
// contient, variables définies. Un bandeau d’une ligne, dans la marge du haut de la diapo (paramètre contexte: d’anime
// et de corriges), toujours au même endroit ; ce qui concerne la commande est encadré (voir), ce qui n’existe pas est
// barré, en tirets (absent).
//   contexte(chemin: "/home/ada/atelier", contenu: ("pionnieres.csv", "scripts/"), voir: ("pionnieres.csv",),
//     autres: 37, variables: (("p", "Ada Lovelace"),))
// machine : une machine distante, un conteneur (pour les autres cours) ; autres : nombre d’entrées non montrées.
#let contexte(compte: "ada", machine: none, chemin: "/home/ada", contenu: (), voir: (), absent: (), autres: 0,
  variables: (), taille: px(21)) = {
  let m(x, ..a) = text(font: mono, size: taille, tracking: 0pt, ..a, x.replace(" ", "\u{a0}"))
  let puce(x, fort: false, manque: false) = box(inset: (x: px(8), y: px(3)), radius: px(6), baseline: 20%,
    fill: if manque { none } else { c.fond },
    stroke: if fort { px(2.5) + c.encre } else if manque { (paint: c.gris, thickness: px(1.5), dash: "dashed") }
      else { px(1) + c.filet },
    if manque { strike(stroke: px(1.5) + c.gris, m(x, fill: c.gris)) }
    else { m(x, fill: c.encre, weight: if fort { 600 } else { 400 }) })
  let segs = chemin.split("/").filter(x => x != "")
  let sep = text(fill: c.gris, size: taille)[ › ]
  block(width: 100%, fill: c.espace, radius: px(10), inset: (x: px(16), y: px(8)), {
    set par(leading: 0.5em)
    text(size: px(18), weight: 600, tracking: px(1), fill: c.gris, maj("contexte"))
    h(px(14))
    m(compte + if machine != none { "@" + machine } else { "" }, fill: c.ardoise)
    h(px(12))
    m("/", fill: c.gris)
    for (i, sg) in segs.enumerate() {
      if i > 0 { m("/", fill: c.gris) }
      if i == segs.len() - 1 { box(stroke: (bottom: px(2.5) + c.bleu), outset: (bottom: px(2)), m(sg, weight: 700, fill: c.encre)) }
      else { m(sg, fill: c.ardoise) }
    }
    if contenu.len() + absent.len() > 0 or autres > 0 {
      h(px(8)); text(size: taille, fill: c.gris)[contient]; h(px(8))
      for x in contenu { puce(x, fort: x in voir); h(px(6)) }
      for x in absent { box(puce(x, manque: true)); h(px(6)) }
      if autres > 0 { text(size: taille * 0.9, fill: c.gris)[\+ #autres autres] }
    }
    if variables.len() > 0 {
      h(px(16)); text(size: taille, fill: c.gris)[variables]; h(px(8))
      for (n, val) in variables { puce(n + "=" + val, fort: ("$" + n) in voir); h(px(6)) }
    }
  })
}

// ---------- Animation : bloc par bloc, puis puce par puce ----------
// Les apparitions passent par uncover (le contenu caché garde sa place) : seules des apparitions,
// exportables en PDF. Un bloc apparaît avec sa première puce, chaque puce suivante au clic suivant.
#let _morceaux(corps) = if corps.func() == [].func() { corps.children } else { (corps,) }
#let _puce(e) = e.func() in (list.item, enum.item)
// Nombre de clics d’un bloc : un par puce, au moins un.
#let etapes-bloc(b) = calc.max(1, _morceaux(b.corps).filter(_puce).len())

#let _corps-anime(corps, debut, uncover) = {
  show list: set block(spacing: 0.5em)
  show enum: set block(spacing: 0.5em)
  let k = 0
  for e in _morceaux(corps) {
    if e.func() == list.item { uncover(str(debut + k) + "-", list(e)); k += 1 }
    else if e.func() == enum.item { uncover(str(debut + k) + "-", enum(start: k + 1, e.body)); k += 1 }
    else { e }
  }
}

// Un bloc animé à partir du clic `debut`.
#let bloc-anime(b, debut, uncover, hauteur: auto) = uncover(str(debut) + "-",
  rendre-bloc((..b, corps: _corps-anime(b.corps, debut, uncover)), hauteur: hauteur))

// Une rangée de blocs côte à côte, à hauteur égale, pour anime().
#let rang(gouttiere: px(32), ..blocs) = (rang: blocs.pos(), gouttiere: gouttiere)

// Source d’un fait, en bas de diapo.
#let source(corps) = place(bottom + left, dy: px(56),
  text(size: px(18), fill: c.gris)[Source : #corps])

// Une scène dessinée au clic k (de 1 à n) ; avant son premier clic, cachée, sa place gardée ; après, k = n + 1 :
// l’état final, sans plus rien mettre en valeur.
#let etape-scene(self, debut, e) = {
  let k = self.subslide - debut + 1
  if k < 1 { hide((e.rendu)(1)) } else { (e.rendu)(calc.min(k, e.scene + 1)) }
}

// Diapo animée : les éléments (rangées de blocs, ou contenu quelconque) apparaissent dans l’ordre,
// bloc par bloc puis puce par puce ; un contenu quelconque (bandeau, schéma) compte pour un clic.
// contexte : le bandeau de contexte (voir contexte(…)), en tête de diapo, toujours au même endroit ; un contenu, ou une
// fonction du clic de la diapo (k => contexte(…)) quand une commande le change.
#let anime(espacement: px(24), note: none, source-de: none, contexte: none, ..elements) = {
  let plan = ()
  let s = 1
  for e in elements.pos() {
    if type(e) == dictionary and "rang" in e {
      let debuts = ()
      for b in e.rang { debuts.push(s); s += etapes-bloc(b) }
      plan.push((e, debuts))
    } else if type(e) == dictionary and "etapes" in e {
      plan.push((e, s)); s += e.etapes
    } else if type(e) == dictionary and "scene" in e {
      plan.push((e, s)); s += e.scene
    } else { plan.push((e, s)); s += 1 }
  }
  slide(repeat: s - 1, self => {
    let (uncover,) = utils.methods(self)
    // dans la marge du haut, au-dessus du surtitre : même place sur chaque diapo, sans prendre celle du sujet
    if contexte != none {
      place(top + left, dy: -px(104), block(width: 100%,
        if type(contexte) == function { contexte(self.subslide) } else { contexte }))
    }
    for (i, (e, d)) in plan.enumerate() {
      if i > 0 { v(espacement) }
      if type(e) == dictionary and "rang" in e {
        rangee(gouttiere: e.gouttiere, poids: e.rang.map(b => b.poids),
          ..e.rang.zip(d).map(((b, db)) => h => bloc-anime(b, db, uncover, hauteur: h)))
      } else if type(e) == dictionary and "etapes" in e { (e.rendu)(uncover, d) }
      else if type(e) == dictionary and "scene" in e { etape-scene(self, d, e) }
      else { uncover(str(d) + "-", e) }
    }
    if source-de != none { source(source-de) }
    if note != none { utils.speaker-note(self: self, note) }
  })
}

// Éléments à plusieurs clics, pour anime() : `pas(n, (uncover, debut) => …)` occupe n clics à partir de debut.
#let pas(n, rendu) = (etapes: n, rendu: rendu)
// Une ligne de `lignes` par clic.
#let lignes-anime(..args) = pas(args.pos().len(), (u, d) => lignes(uncover: u, debut: d, ..args))
// Terminal dont les morceaux apparaissent un par clic : terminal-etapes([```…```], [```…```], titre: …).
#let terminal-etapes(titre: "Terminal", taille: px(20), ..morceaux) = pas(morceaux.pos().len(), (u, d) =>
  terminal(titre: titre, taille: taille, morceaux.pos().enumerate().map(((i, m)) => u(str(d + i) + "-", m)).join()))
// Plan du cours, une partie par clic.
#let plan-anime(..parties) = pas(parties.pos().len(), (u, d) => plan-cours(uncover: (v, x) => u(str(d - 1 + int(v.split("-").at(0))) + "-", x), ..parties))

// ---------- Scène : un dessin qui suit le clic ----------
// Pour anime() : scene(n, k => …) occupe n clics ; k va de 1 (son premier clic) à n. Le dessin est une fonction
// de k : la diapo montre une transformation (départ, action, arrivée), chaque clic la fait avancer d’un cran.
// Plusieurs dessins qui avancent ensemble (terminal et schéma) se placent dans la même scène.
// Après son dernier clic, la scène reçoit k = n + 1 : son état final, rien n’y est plus mis en valeur.
#let scene(n, rendu) = (scene: n, rendu: rendu)

// ---------- Commande ou sortie annotée ----------
// Un morceau désigné, relié par un trait à sa légende ; les légendes se placent seules, d’après la colonne
// du morceau (police à chasse fixe), sur des rangées au-dessus ou au-dessous du cadre sans se chevaucher.
//   annote("-l", legende: [option]) : le morceau « -l », trouvé dans la première ligne qui le contient ;
//   annote("rwx", "ada", legende: […]) : deux morceaux reliés à la même légende ;
//   annote((ligne: 2, texte: ";", n: 1), …) : le n-ième « ; » de la ligne 2 ; annote((3, 7), …) : colonnes 3 à 6
//   (de la ligne 0, ou de `ligne:`) ; annote((ligne: 2, cols: (3, 7)), …) : les mêmes, ligne 2.
// cote : "bas" (défaut), "haut", ou "droite" (à droite du cadre, pour une ligne entière ou un morceau en fin de ligne).
// clic : le clic de la scène où l’annotation paraît (défaut : celui qui suit la précédente, en partant de 2).
// Au clic où il paraît, le morceau est encadré et sa légende aussi ; ensuite, il reste souligné (garde: true :
// encadré). Sans legende : seulement la marque. pont: true (plusieurs morceaux) : le trait part du premier morceau,
// et un pont, de l’autre côté du cadre, le relie aux suivants (un champ et ce qui le concerne, sur la même ligne).
// Une légende passée reste, grisée, si l’annotation en cours porte sur la même ligne (la suite décompose cette ligne) ;
// sinon elle s’efface. reste: true ou false impose l’un ou l’autre. Au plus cinq légendes à l’écran : les plus anciennes
// s’effacent au-delà (mieux : scinder la diapo).
#let annote(..cibles, legende: none, cote: "bas", clic: auto, ligne: auto, garde: false, pont: false, reste: auto) = (
  cibles: cibles.pos(), legende: legende, cote: cote, clic: clic, ligne: ligne, garde: garde, pont: pont, reste: reste)

// Tabulations développées comme dans un terminal (arrêts toutes les 8 colonnes).
#let _tabs(s) = if not s.contains("\t") { s } else {
  let r = ""
  for ch in s.clusters() { if ch == "\t" { r += " " * (8 - calc.rem(r.clusters().len(), 8)) } else { r += ch } }
  r
}

// Une ligne : "texte" (clic 1), ("texte", clic), ou des morceaux ((“texte”, clic), …) qui paraissent l’un après l’autre.
#let _morceaux-ligne(l) = {
  if type(l) == str { ((_tabs(l), 1),) }
  else if type(l) == array and l.len() == 2 and type(l.at(0)) == str and type(l.at(1)) == int { ((_tabs(l.at(0)), l.at(1)),) }
  else { l.map(m => if type(m) == str { (m, 1) } else { m }) }
}
// Clic de chaque annotation (auto : celui qui suit la précédente) et nombre de clics de la scène.
#let _clics-annotations(lignes, annotations) = {
  let dernier = 1
  let clics = ()
  for a in annotations {
    let k = if a.clic == auto { dernier + 1 } else { a.clic }
    clics.push(k)
    dernier = k
  }
  let pieces = lignes.map(_morceaux-ligne).flatten().chunks(2).map(m => m.at(1))
  (clics, calc.max(1, ..clics, ..pieces))
}
// Position (en octets) de la n-ième occurrence de s dans t.
#let _occurrence(t, s, n) = {
  let depart = 0
  for i in range(n) {
    let p = t.slice(depart).position(s)
    if p == none { return none }
    if i == n - 1 { return depart + p }
    depart += p + s.len()
  }
}

#let terminal-annote(lignes, ..annotations, etape: 1000, taille: px(26), fond: "terminal", nom: none,
  taille-legende: px(26), largeur-legende: px(900)) = context layout(dispo => {
  let W = dispo.width
  let lg = lignes.map(_morceaux-ligne)
  let textes = lg.map(ms => ms.map(m => m.at(0)).join())
  // espaces insécables : une espace en tête de morceau compte, comme dans le terminal
  let chasse(s, ..args) = text(font: mono, size: taille, tracking: 0pt, spacing: 100%, ..args, s.replace(" ", "\u{a0}"))
  let cw = measure(chasse("0")).width
  let lh = taille * 1.45
  let sombre = fond == "terminal"
  let (ix, iy) = (px(22), px(12))
  let entete = if nom != none { px(40) } else { 0pt }
  let lb = calc.max(..textes.map(t => t.clusters().len())) * cw + 2 * ix
  let hb = entete + lg.len() * lh + 2 * iy
  let marque = if sombre { c.prompt } else { c.bleu }
  let (clics, _) = _clics-annotations(lignes, annotations.pos())

  // Morceaux désignés : ligne, colonnes de début et de fin.
  let anns = annotations.pos().zip(clics).map(((a, k)) => {
    let spans = a.cibles.map(ci => {
      let (l, debut, fin) = if type(ci) == array {
        (if a.ligne == auto { 0 } else { a.ligne }, ci.at(0), ci.at(1))
      } else if type(ci) == dictionary and "cols" in ci {
        (ci.at("ligne", default: if a.ligne == auto { 0 } else { a.ligne }), ci.cols.at(0), ci.cols.at(1))
      } else {
        let (l, s, n) = if type(ci) == dictionary { (ci.at("ligne", default: a.ligne), ci.texte, ci.at("n", default: 1)) }
          else { (a.ligne, ci, 1) }
        if l == auto { l = range(textes.len()).find(i => _occurrence(textes.at(i), s, n) != none) }
        assert(l != none, message: "annote : morceau introuvable : " + s)
        let p = _occurrence(textes.at(l), s, n)
        assert(p != none, message: "annote : morceau introuvable : " + s)
        let d = textes.at(l).slice(0, p).clusters().len()
        (l, d, d + s.clusters().len())
      }
      (l: l, x0: ix + debut * cw, x1: ix + fin * cw, yt: entete + iy + l * lh)
    })
    let etiq = if a.legende != none {
      let corps(actif, w) = box(width: w, inset: (x: px(10), y: px(5)), radius: px(6), fill: c.fond,
        stroke: if actif { px(2.5) + c.encre } else { none },
        text(size: taille-legende, fill: if actif { c.encre } else { c.ardoise }, a.legende))
      // à droite du cadre : la place qui reste jusqu’au bord
      let wmax = if a.cote == "droite" { calc.max(px(200), W - lb - px(28)) } else { largeur-legende }
      let w = calc.min(measure(corps(true, auto)).width, wmax)
      (corps: corps, w: w, h: measure(corps(true, w)).height)
    }
    (..a, spans: spans, clic: k, etiq: etiq)
  })

  // Rangées de légendes, d’un côté : la première rangée libre, sans chevaucher ni couper un trait.
  let (gl, ecart) = (px(10), px(16))
  // les ponts passent de l’autre côté du cadre : ils écartent d’autant les légendes de ce côté
  let ponts(cote) = anns.filter(a => a.pont and a.spans.len() > 1 and a.cote == cote)
  let g0-de(cote) = px(22) + ponts(if cote == "haut" { "bas" } else { "haut" }).len() * px(16)
  let (g0h, g0b) = (g0-de("haut"), g0-de("bas"))
  let chevauche(a, b) = a.at(0) < b.at(1) + ecart and b.at(0) < a.at(1) + ecart
  let placer(cote) = {
    let places = ()
    // de droite à gauche : une légende s’étend vers la droite, sous (ou sur) celles des morceaux plus à droite,
    // sans couper leurs traits
    let ordre = anns.enumerate().filter(((i, a)) => a.etiq != none and a.cote == cote)
      .sorted(key: ((i, a)) => {
        let ss = if a.pont { a.spans.slice(0, 1) } else { a.spans }
        -ss.map(s => (s.x0 + s.x1) / 2).sum() / ss.len() / 1pt
      })
    for (i, a) in ordre {
      let (w, h) = (a.etiq.w, a.etiq.h)
      let xcs = (if a.pont { a.spans.slice(0, 1) } else { a.spans }).map(s => (s.x0 + s.x1) / 2)
      let m = calc.min(px(16), w / 2)
      // positions essayées : alignée sur le début du morceau, puis sur sa fin (vers la gauche), puis centrée
      let xm = xcs.sum() / xcs.len()
      let candidats = if xcs.len() == 1 {
        (a.spans.at(0).x0 - px(10), a.spans.at(0).x1 + px(10) - w, xm - w / 2)
      } else { (xm - w / 2,) }
      let essai(lx0) = {
        let lx = calc.max(0pt, calc.min(lx0, W - w))
        let att = xcs.map(x => calc.max(lx + m, calc.min(x, lx + w - m)))
        let traits = xcs.zip(att).map(((x, p)) => (calc.min(x, p) - px(4), calc.max(x, p) + px(4)))
        let gene(r, strict) = places.any(p => (p.r == r and chevauche((lx, lx + w), p.ix))
            or (strict and p.r < r and traits.any(t => chevauche(t, p.ix)))
            or (strict and p.r > r and p.traits.any(t => chevauche(t, (lx, lx + w)))))
        let r = 0
        while r < 8 and gene(r, true) { r += 1 }
        (r: r, lx: lx, att: att, traits: traits, gene: gene)
      }
      let essais = candidats.map(essai)
      let bon = essais.filter(e => e.r < 8)
      let choix = if bon.len() > 0 { bon.sorted(key: e => e.r).first() } else {
        // aucune rangée sans croisement : la première où la légende ne chevauche aucune autre
        let e = essais.first()
        let r = 0
        while (e.gene)(r, false) { r += 1 }
        (..e, r: r)
      }
      places.push((i: i, r: choix.r, ix: (choix.lx, choix.lx + w), lx: choix.lx, att: choix.att, xcs: xcs, traits: choix.traits))
    }
    places
  }
  let haut = placer("haut")
  let bas = placer("bas")
  let rangees(ps) = if ps.len() == 0 { 0 } else { calc.max(..ps.map(p => p.r)) + 1 }
  let hl(cote) = calc.max(0pt, ..anns.filter(a => a.etiq != none and a.cote == cote).map(a => a.etiq.h))
  let (lhh, lhb) = (hl("haut"), hl("bas"))
  let Ht = if rangees(haut) > 0 { g0h + rangees(haut) * (lhh + gl) } else { g0h - px(22) }
  let Hb = if rangees(bas) > 0 { g0b + rangees(bas) * (lhb + gl) } else { g0b - px(22) }
  // à droite : chaque légende en face de sa ligne, poussée vers le bas si elle chevaucherait la précédente
  let droite = anns.enumerate().filter(((i, a)) => a.etiq != none and a.cote == "droite")
    .sorted(key: ((i, a)) => a.spans.at(0).yt / 1pt)
  let hauts-d = (:)
  let bas-prec = -1000pt
  for (i, a) in droite {
    let t = calc.max(a.spans.at(0).yt + lh / 2 - a.etiq.h / 2, bas-prec + px(6))
    hauts-d.insert(str(i), t)
    bas-prec = t + a.etiq.h
  }
  let Hd = calc.max(0pt, bas-prec)

  block(width: W, height: calc.max(Ht + hb + Hb, Ht + Hd), {
    // le cadre et ses lignes
    if sombre { place(top + left, dy: Ht, rect(width: lb, height: hb, fill: c.nuit, radius: px(12))) }
    else {
      place(top + left, dy: Ht, rect(width: lb, height: hb, fill: c.espace, stroke: px(1.5) + c.filet, radius: px(12)))
      if nom != none {
        place(top + left, dy: Ht, rect(width: lb, height: entete, fill: c.filet, radius: (top: px(12))))
        place(top + left, dx: ix, dy: Ht, box(height: entete, align(horizon,
          text(font: mono, size: px(20), weight: 600, fill: c.ardoise, tracking: 0pt, nom))))
      }
    }
    for (l, ms) in lg.enumerate() {
      let t = textes.at(l)
      let col = 0
      for (s, k) in ms {
        if k <= etape {
          let corps = if not sombre { chasse(s, fill: c.encre) }
            else if t.starts-with("# ") { chasse(s, fill: c.commentaire) }
            else if col == 0 and s.starts-with("$ ") { chasse("$", fill: c.prompt); chasse(s.slice(1), fill: c.texte-term) }
            else { chasse(s, fill: c.texte-term) }
          place(top + left, dx: ix + col * cw, dy: Ht + entete + iy + l * lh, box(height: lh, align(horizon, corps)))
        }
        col += s.clusters().len()
      }
    }
    // marques, traits et légendes
    let dessiner(a, p, cote) = {
      let actif = a.clic == etape
      for (j, s) in a.spans.enumerate() {
        let y = Ht + s.yt
        if actif or a.garde {
          place(top + left, dx: s.x0 - px(4), dy: y + px(1), rect(width: s.x1 - s.x0 + px(8), height: lh - px(2),
            stroke: (if actif { px(3.5) } else { px(2) }) + marque, radius: px(5)))
        } else {
          place(top + left, line(start: (s.x0, y + lh - px(3)), end: (s.x1, y + lh - px(3)), stroke: px(3) + marque))
        }
        let (ep, coul) = if actif { (px(3), c.encre) } else { (px(1.5), c.gris) }
        if a.pont and a.spans.len() > 1 and cote != "droite" {
          // pont, de l’autre côté du cadre
          let rang-pont = ponts(cote).position(b => b == a)
          let xc = (s.x0 + s.x1) / 2
          let (bord, depart, yp) = if cote == "bas" { (Ht, y + px(1), Ht - px(12) - rang-pont * px(16)) }
            else { (Ht + hb, y + lh - px(1), Ht + hb + px(12) + rang-pont * px(16)) }
          place(top + left, line(start: (xc, depart), end: (xc, bord), stroke: ep + marque))
          place(top + left, line(start: (xc, bord), end: (xc, yp), stroke: ep + coul))
          if j > 0 {
            let x0 = (a.spans.at(0).x0 + a.spans.at(0).x1) / 2
            place(top + left, line(start: (x0, yp), end: (xc, yp), stroke: ep + coul))
          }
          if j > 0 { continue }
        }
        if p == none { continue }
        let xc = p.xcs.at(j)
        if cote == "droite" {
          let yc = y + lh / 2
          place(top + left, line(start: (s.x1 + px(4), yc), end: (lb + px(28), Ht + p.haut + a.etiq.h / 2), stroke: ep + coul))
        } else {
          let (bord, depart, arrivee) = if cote == "bas" {
            let yl = Ht + hb + g0b + p.r * (lhb + gl)
            (Ht + hb, y + lh - px(1), yl)
          } else {
            let yl = Ht - g0h - p.r * (lhh + gl)
            (Ht, y + px(1), yl)
          }
          place(top + left, line(start: (xc, depart), end: (xc, bord), stroke: ep + marque))
          place(top + left, line(start: (xc, bord), end: (p.att.at(j), arrivee), stroke: ep + coul))
        }
      }
      if p != none {
        let e = (a.etiq.corps)(actif, a.etiq.w)
        if cote == "bas" { place(top + left, dx: p.lx, dy: Ht + hb + g0b + p.r * (lhb + gl), e) }
        else if cote == "haut" { place(top + left, dx: p.lx, dy: Ht - g0h - p.r * (lhh + gl) - a.etiq.h, e) }
        else { place(top + left, dx: lb + px(28), dy: Ht + p.haut, e) }
      }
    }
    // Ce qui reste à l’écran : l’annotation en cours, et les précédentes rattachées (même ligne, ou reste: true),
    // au plus cinq légendes.
    let parues = anns.enumerate().filter(((i, a)) => a.clic <= etape)
    let derniere = if parues.len() > 0 { calc.max(..parues.map(((i, a)) => a.clic)) } else { 0 }
    let lignes-de(a) = a.spans.map(s => s.l)
    let courantes = parues.filter(((i, a)) => a.clic == derniere).map(((i, a)) => lignes-de(a)).flatten()
    let gardees = parues.filter(((i, a)) => a.clic == derniere or a.reste == true
      or (a.reste == auto and lignes-de(a).any(l => l in courantes)))
    let avec = gardees.filter(((i, a)) => a.etiq != none)
    let trop = avec.sorted(key: ((i, a)) => a.clic).slice(0, calc.max(0, avec.len() - 5)).map(((i, a)) => i)
    let visibles = gardees.map(((i, a)) => i).filter(i => i not in trop)
    for (i, a) in anns.enumerate() {
      if i not in visibles { continue }
      let p = if a.etiq == none { none } else if a.cote == "haut" { haut.find(q => q.i == i) }
        else if a.cote == "bas" { bas.find(q => q.i == i) } else { (xcs: a.spans.map(s => s.x1), haut: hauts-d.at(str(i))) }
      dessiner(a, p, a.cote)
    }
  })
})

// Pour anime() : la même chose, un clic par ligne ou par annotation.
#let commande-annotee(lignes, ..args) = {
  let (_, n) = _clics-annotations(lignes, args.pos())
  scene(n, k => terminal-annote(lignes, ..args, etape: k))
}

// ---------- Repère d’étape ----------
// Le numéro de l’étape en cours, posé sur ce qu’elle change (et devant sa légende) : un carré bleu à chiffre blanc,
// distinct des prises rondes et blanches des processus.
#let pastille(n, t: px(22)) = box(fill: c.bleu, stroke: px(2) + c.fond, radius: px(6), inset: (x: t * 0.32, y: t * 0.12),
  baseline: 15%, text(size: t, weight: 700, fill: c.fond, tracking: 0pt, str(n)))

// ---------- Schéma à états ----------
// Des nœuds nommés, des liens entre eux, et une suite d’états dont chacun ne dit que ce qui change.
//   schema-etats(hauteur: 300, etape: k,
//     noeuds: (ls: (x: 300, y: 80, l: 200, h: 160, genre: "processus", titre: "ls"),
//              ecran: (x: 700, y: 60, l: 400, h: 120, genre: "terminal", contenu: ("$ ls",))),
//     liens: (sortie: (de: "ls.1", vers: "ecran")),
//     etats: ((:), (liens: (sortie: (vers: "f")), noeuds: (f: (x: …, genre: "fichier", titre: "sortie.txt")))))
// Position : x, y, l, h en px de la maquette ; ou, avec grille: (x: pas, y: pas, ecart: px), col, lig (et larg, haut,
// en cases) : le nœud occupe sa case moins l’écart. Genres : "processus" (fond nuit, prises 0 à gauche, 1 et 2 à droite,
// numérotées ; attente: true : pas encore lancé, en tirets ; ports: (…) pour d’autres prises), "terminal" (lignes,
// invite colorée), "fichier" (nom en tête, pied à droite, contenu en lignes ; () : vide), "flux" (ce qui circule dans un
// tube : cadre en tirets, sans nom), "boite" (défaut : titre, sous-titre ; attente: true), "texte" (une légende, de
// largeur l). marque: (i, …) encadre des lignes du contenu (celle dont parle une légende).
// Un lien va de "nœud.prise" (ou "nœud" : le côté qui fait face) à "nœud.prise" ; prises : celles du genre, ou
// g, d, h, b (milieu d’un côté) ; options : etiquette, pos (0 à 1, place de l’étiquette), donnee (ce qui circule,
// sur fond de terminal ; pos-donnee), tirets, motif ("dotted" : voie non suivie), fleche, fort (impose ou retire
// la mise en valeur).
// État k = état k − 1 + etats.at(k − 1) ; une valeur none retire le nœud ou le lien. Repère d’étape : ce qui change
// au clic k porte le numéro numero(k) (défaut k − 1 : l’état 1 est le départ) — pastille sur le nœud, devant la
// légende, en face de la première ligne nouvelle d’un terminal, dont les lignes précédentes passent en gris ; un lien
// changé s’épaissit, et laisse son ancien tracé en pointillé.
#let schema-etats(hauteur: 300, noeuds: (:), liens: (:), etats: ((:),), etape: 1000, taille: px(22), grille: none,
  numero: k => if k > 1 { k - 1 }) = context {
  let appliquer(s, patch) = {
    for genre in ("noeuds", "liens") {
      for (nom, v) in patch.at(genre, default: (:)) {
        if v == none { let _ = s.at(genre).remove(nom, default: none) }
        else { s.at(genre).insert(nom, s.at(genre).at(nom, default: (:)) + v) }
      }
    }
    s
  }
  // position en grille : col, lig, larg, haut → x, y, l, h
  let placer(n) = if grille != none and "col" in n {
    let e = grille.at("ecart", default: 40)
    (..n, x: n.col * grille.x, y: n.lig * grille.y, l: n.at("larg", default: 1) * grille.x - e,
      h: n.at("haut", default: 1) * grille.y - e)
  } else { n }
  let k = calc.max(1, calc.min(etape, etats.len()))
  let etat = (noeuds: noeuds, liens: liens)
  let avant = none
  for i in range(k) { avant = etat; etat = appliquer(etat, etats.at(i)) }
  etat.noeuds = etat.noeuds.pairs().map(((nom, n)) => (nom, placer(n))).to-dict()
  if avant != none { avant.noeuds = avant.noeuds.pairs().map(((nom, n)) => (nom, placer(n))).to-dict() }
  // au-delà du dernier état (scène finie, ou dessin statique), rien n’est mis en valeur
  let actif = etape <= etats.len() and (k >= 2 or numero(1) != none)
  let change = if actif { etats.at(k - 1) } else { (:) }
  let num = if actif { numero(k) } else { none }
  let neuf(genre, nom) = nom in change.at(genre, default: (:)) and change.at(genre).at(nom) != none

  let prises-genre(n) = n.at("ports", default: if n.at("genre", default: "boite") == "processus" {
    ("0": ("g", 0.5), "1": ("d", 0.3), "2": ("d", 0.72)) } else { (:) })
  let point(n, cote, t) = if cote == "g" { (n.x, n.y + t * n.h) } else if cote == "d" { (n.x + n.l, n.y + t * n.h) }
    else if cote == "h" { (n.x + t * n.l, n.y) } else { (n.x + t * n.l, n.y + n.h) }
  let centre(n) = (n.x + n.l / 2, n.y + n.at("h", default: 0) / 2)
  let bout(s, ns, autre) = {
    let (nom, prise) = if s.contains(".") { let p = s.split("."); (p.at(0), p.at(1)) } else { (s, none) }
    let n = ns.at(nom)
    let pr = prises-genre(n)
    if prise != none and prise in pr { let (cote, t) = pr.at(prise); return point(n, cote, t) }
    if prise != none { return point(n, prise, 0.5) }
    let (cx, cy) = centre(n)
    let (ox, oy) = autre
    let (dx, dy) = ((ox - cx) / n.l, (oy - cy) / calc.max(n.at("h", default: 1), 1))
    point(n, if calc.abs(dx) >= calc.abs(dy) { if dx > 0 { "d" } else { "g" } } else { if dy > 0 { "b" } else { "h" } }, 0.5)
  }
  let geometrie(lien, ns) = {
    let cible(s) = centre(ns.at(s.split(".").at(0)))
    (bout(lien.de, ns, cible(lien.vers)), bout(lien.vers, ns, cible(lien.de)))
  }
  let ligne-mono(s, t, sombre, gris) = {
    let ins(x) = x.replace(" ", "\u{a0}")  // les espaces en tête comptent
    text(font: mono, size: t, tracking: 0pt, spacing: 100%,
      if type(s) != str { s }
      else if gris { text(fill: if sombre { c.commentaire.darken(25%) } else { c.gris }, ins(s)) }
      else if not sombre { ins(s) }
      else if s.starts-with("$ ") { text(fill: c.prompt, "$"); text(fill: c.texte-term, ins(s.slice(1))) }
      else if s.starts-with("# ") { text(fill: c.commentaire, ins(s)) } else { text(fill: c.texte-term, ins(s)) })
  }
  // Lignes à pas fixe : anciennes (grisées), marques (encadrées), pastille en face de la première ligne nouvelle.
  let pas-ligne(t) = t * 1.42
  let lignes(contenu, t, sombre, largeur, anciens: 0, marques: (), pastille-a: none) = if type(contenu) == array {
    let pl = pas-ligne(t)
    box(width: largeur, height: contenu.len() * pl, {
      for (i, s) in contenu.enumerate() {
        place(top + left, dy: i * pl, box(height: pl, align(horizon, ligne-mono(s, t, sombre, i < anciens))))
        if i in marques {
          let w = measure(ligne-mono(s, t, sombre, false)).width
          place(top + left, dx: -px(5), dy: i * pl, rect(width: w + px(10), height: pl,
            stroke: px(3) + (if sombre { c.prompt } else { c.bleu }), radius: px(5)))
        }
      }
      if pastille-a != none and pastille-a < contenu.len() {
        place(top + right, dy: pastille-a * pl + (pl - t * 1.3) / 2, pastille(num, t: t * 0.9))
      }
    })
  } else { contenu }
  // lignes déjà présentes à l’état précédent (le contenu s’allonge) : elles passent en gris
  let anciens-de(nom, n) = {
    if not actif or avant == none or nom not in avant.noeuds or not neuf("noeuds", nom) { return 0 }
    let a = avant.noeuds.at(nom).at("contenu", default: none)
    let b = n.at("contenu", default: none)
    if type(a) == array and type(b) == array and a.len() <= b.len() and b.slice(0, a.len()) == a { a.len() } else { 0 }
  }

  let noeud(nom, n) = {
    let genre = n.at("genre", default: "boite")
    let t = n.at("taille", default: taille)
    let (lw, hw) = (px(n.l), px(n.at("h", default: 0)))
    let nv = neuf("noeuds", nom) and num != none
    let marques = n.at("marque", default: ())
    let corps = if genre == "processus" {
      let attente = n.at("attente", default: false)
      let fond-p = if attente { none } else { c.nuit }
      let encre-p = if attente { c.gris } else { c.fond }
      rect(width: lw, height: hw, fill: fond-p, radius: px(10),
        stroke: if attente { (paint: c.gris, thickness: px(3), dash: "dashed") } else { none },
        align(center + horizon, stack(spacing: px(8),
          text(font: mono, size: n.at("taille-titre", default: px(34)), weight: 600, fill: encre-p, tracking: 0pt,
            n.at("titre", default: nom)),
          ..if "sous" in n { (text(size: px(22), fill: if attente { c.gris } else { c.texte-term }, n.sous),) }
        )))
    } else if genre == "terminal" {
      let anc = anciens-de(nom, n)
      let ct = n.at("contenu", default: ())
      rect(width: lw, height: hw, fill: c.nuit, radius: px(12), inset: (x: px(16), y: px(12)),
        align(left + top, {
          if "titre" in n { text(size: px(18), weight: 600, tracking: px(2), fill: c.prompt, maj(n.titre)); v(px(6), weak: true) }
          lignes(ct, t, true, lw - px(32), anciens: anc, marques: marques,
            pastille-a: if nv and type(ct) == array and ct.len() > anc { anc })
        }))
    } else if genre == "fichier" {
      let anc = anciens-de(nom, n)
      box(width: lw, height: hw, fill: c.espace, stroke: px(1.5) + c.filet, radius: px(10), clip: true, stack(
        block(width: 100%, height: px(38), fill: c.filet, inset: (x: px(12)), align(horizon, {
          text(font: mono, size: px(20), weight: 600, fill: c.ardoise, tracking: 0pt, n.at("titre", default: nom))
          if nv { h(px(10)); pastille(num, t: px(19)) }
          if "pied" in n { h(1fr); text(size: px(18), fill: c.ardoise, n.pied) }
        })),
        block(width: 100%, inset: (x: px(12), y: px(10)), {
          let ct = n.at("contenu", default: none)
          if ct == () { text(size: px(19), fill: c.gris)[(vide)] }
          else if ct != none { lignes(ct, t, false, lw - px(24), anciens: anc, marques: marques) }
        }),
      ))
    } else if genre == "flux" {
      // ce qui circule (dans un tube) : pas un fichier, un cadre en tirets sans nom
      rect(width: lw, height: hw, stroke: (paint: c.gris, thickness: px(2), dash: "dashed"), radius: px(10),
        inset: (x: px(14), y: px(10)), align(left + top,
          lignes(n.at("contenu", default: ()), t, false, lw - px(28), marques: marques)))
    } else if genre == "texte" {
      let corps-t = { if nv { pastille(num, t: t * 0.9); h(t * 0.4) }; n.at("contenu", default: []) }
      // role : la légende prend le fond et le pictogramme d’un rôle (precaution, danger…)
      if n.at("role", default: none) != none { box(width: lw, note(role: n.role, taille: t, corps-t)) } else { box(width: lw, text(size: t, corps-t)) }
    } else {
      // boîte ; attente: true : ce qui n’a pas lieu (commande non lancée), en tirets, sans fond
      let attente = n.at("attente", default: false)
      rect(width: lw, height: hw, fill: if attente { none } else { c.appli }, radius: px(12),
        stroke: if attente { (paint: c.gris, thickness: px(3), dash: "dashed") } else { px(2) + c.bleu.transparentize(50%) },
        align(center + horizon, stack(spacing: px(6),
          text(size: n.at("taille-titre", default: px(28)), weight: 600, fill: if attente { c.gris } else { c.encre },
            n.at("titre", default: nom)),
          ..if "sous" in n { (text(size: px(22), fill: if attente { c.gris } else { c.ardoise }, n.sous),) })))
    }
    place(top + left, dx: px(n.x), dy: px(n.y), corps)
    // pastille au coin d’une boîte ou d’un processus changés (les autres genres la portent dans leur contenu)
    if nv and genre in ("processus", "boite") {
      place(top + left, dx: px(n.x + n.l - 16), dy: px(n.y - 16), pastille(num))
    }
  }
  // prises numérotées (0, 1, 2…) : celles des processus seulement ; les autres ne sont que des points d’attache
  let prises(nom, n) = if n.at("genre", default: "boite") == "processus" { for (p, (cote, t)) in prises-genre(n) {
    if p.len() > 2 { continue }  // un nom long (arg…) : un point d’attache, sans cercle numéroté
    let (x, y) = point(n, cote, t)
    place(top + left, dx: px(x - 20), dy: px(y - 20), circle(radius: px(20), fill: c.fond, stroke: px(3) + c.nuit,
      align(center + horizon, text(font: mono, size: px(24), weight: 700, fill: c.encre, tracking: 0pt, p))))
  } }
  let lien(nom, li) = {
    let fort = if not actif { false } else { li.at("fort", default: neuf("liens", nom)) }
    let (a, b) = geometrie(li, etat.noeuds)
    let ancien = if avant != none { avant.liens.at(nom, default: none) }
    // l’ancien tracé, en pointillé, si ses deux bouts existent encore
    if fort and ancien != none and (ancien.de, ancien.vers).all(b => b.split(".").at(0) in etat.noeuds) {
      let (a0, b0) = geometrie(ancien, avant.noeuds)
      if a0 != a or b0 != b { fleche-pose(..a0, ..b0, couleur: c.gris, ep: 2, motif: "dotted") }
    }
    let motif = li.at("motif", default: if li.at("tirets", default: false) { "dashed" } else { none })
    fleche-pose(..a, ..b, couleur: if fort { c.encre } else { c.ardoise }, ep: if fort { 6 } else { 3 }, motif: motif,
      pointe: li.at("fleche", default: true))
    if "etiquette" in li and li.etiquette != none {
      let t = li.at("pos", default: 0.5)
      let (x, y) = (a.at(0) + t * (b.at(0) - a.at(0)), a.at(1) + t * (b.at(1) - a.at(1)))
      let e = box(fill: c.fond, inset: (x: px(8), y: px(4)), radius: px(6),
        stroke: if fort { px(2.5) + c.encre } else { px(1) + c.filet }, text(size: li.at("taille", default: taille), li.etiquette))
      let m = measure(e)
      place(top + left, dx: px(x) - m.width / 2, dy: px(y) - m.height / 2, e)
    }
    // ce qui circule sur le lien : un extrait de texte, sur fond de terminal
    if "donnee" in li and li.donnee != none {
      let t = li.at("pos-donnee", default: 0.62)
      let (x, y) = (a.at(0) + t * (b.at(0) - a.at(0)), a.at(1) + t * (b.at(1) - a.at(1)))
      let e = box(fill: c.nuit, inset: (x: px(10), y: px(5)), radius: px(6), {
        show raw: set text(fill: c.texte-term)
        text(size: taille, fill: c.texte-term, li.donnee)
      })
      let m = measure(e)
      place(top + left, dx: px(x) - m.width / 2, dy: px(y) - m.height / 2, e)
    }
  }
  block(width: 100%, height: px(hauteur), {
    for (nom, n) in etat.noeuds { noeud(nom, n) }
    for (nom, li) in etat.liens { lien(nom, li) }
    for (nom, n) in etat.noeuds { prises(nom, n) }
  })
}

// ---------- Ligne réécrite par Bash ----------
// Les six étapes de l’expansion, une rangée par étape (mêmes noms et même ordre que l’artefact expansions-bash) :
// chaque mot reste dans la colonne du mot tapé dont il vient ; à l’étape en cours, ce qui change est encadré, et sa
// légende dit pourquoi. Un mot : (origine, "texte") ou (origine, "texte", genre) ; genre "x" : produit par une
// expansion (fond teinté), "q" : protégé par des guillemets (souligné), "xq" : les deux. Une espace dans un mot
// s’écrit « · » ; un mot vide, « ∅ ». La commande tapée est en tête ; sortie (lignes) : la preuve, au dernier clic.
//   ligne-reecrite(etape: k, commande: "$ printf '[%s]\n' $p", rangs: (r1, …, r6), notes: (n1, …, n6), sortie: (…))
#let noms-expansion = ("Mots", "Accolades", "Tilde, $, $( )", "Découpage", "Chemins", "Guillemets")
#let ligne-reecrite(etape: 1000, commande: none, rangs: (), notes: (), sortie: none, taille: px(22),
  largeur-sortie: px(290), note-fin: none) = context layout(dispo => {
  let k = etape
  let fini = k > rangs.len() + (if sortie != none { 1 } else { 0 })
  let m(x, ..a) = text(font: mono, size: taille, tracking: 0pt, ..a, x.replace(" ", "\u{a0}"))
  let norm(w) = (o: w.at(0), t: w.at(1), g: if w.len() > 2 { w.at(2) } else { "" })
  let rs = rangs.map(r => r.map(norm))
  let origines = rs.first().map(w => w.o).dedup()
  let puce(w, etat) = {
    // etat : "courant" (changé à l’étape en cours), "present", "passe"
    let teinte = w.g.contains("x")
    let corps = if w.t == "∅" { m("∅", fill: c.gris) } else {
      let txt = w.t.split("·").map(x => m(x, fill: if etat == "passe" { c.ardoise } else { c.encre }))
        .join(m("·", fill: c.gris))
      if w.g.contains("q") { underline(stroke: px(2.5) + c.bleu, offset: px(4), txt) } else { txt }
    }
    box(inset: (x: px(7), y: px(6)), radius: px(5), baseline: 25%,
      fill: if teinte { c.appli } else { c.fond },
      stroke: if etat == "courant" { px(3) + c.encre } else { px(1) + c.filet },
      corps)
  }
  let groupe(r, o) = r.filter(w => w.o == o)
  let gap = px(8)
  let largeur-groupe(ws) = if ws.len() == 0 { 0pt } else {
    ws.map(w => measure(puce(w, "present")).width).sum() + gap * (ws.len() - 1) }
  let lo = origines.map(o => calc.max(..rs.map(r => largeur-groupe(groupe(r, o)))))
  let lab-l = px(270)
  let gg = px(18)
  let rangee(i) = {
    let r = rs.at(i)
    let courant = i + 1 == k
    let passe = i + 1 < k or fini
    grid(columns: (lab-l, ..lo), column-gutter: gg, align: horizon,
      text(size: px(23), fill: if courant { c.encre } else { c.ardoise }, weight: if courant { 700 } else { 400 },
        { pastille(i + 1, t: px(20)); h(px(10)); noms-expansion.at(i) }),
      ..origines.map(o => {
        let ws = groupe(r, o)
        let prec = if i > 0 { groupe(rs.at(i - 1), o) } else { () }
        let change = i == 0 or ws != prec
        ws.map(w => puce(w, if courant and change { "courant" } else if passe { "passe" } else { "present" })).join(h(gap))
      }))
  }
  let hr = measure(rangee(0)).height
  let corps-rangs = stack(spacing: px(24), ..range(rs.len()).map(i => if i + 1 <= k { rangee(i) } else { hide(rangee(i)) }))
  let note-courante = if k >= 1 and k <= notes.len() { notes.at(k - 1) } else if k > rs.len() { note-fin }
  let a-droite = sortie != none
  stack(spacing: px(14),
    if commande != none { terminal(titre: none, taille: px(26), raw(commande, block: true)) },
    grid(columns: if a-droite { (1fr, largeur-sortie) } else { (1fr,) }, column-gutter: px(24),
      corps-rangs,
      ..if a-droite {
        let t = terminal(titre: none, taille: px(19), raw(sortie.join("\n"), block: true))
        (if k > rs.len() { t } else { hide(t) },)
      }),
    block(height: px(80), width: 100%, if note-courante != none {
      text(size: px(27), { if k <= rs.len() { pastille(k, t: px(24)); h(px(10)) }; note-courante })
    }),
  )
})
#let reecriture-anime(..args) = {
  let n = args.named().rangs.len() + if args.named().at("sortie", default: none) != none { 1 } else { 0 }
  scene(n, k => ligne-reecrite(..args, etape: k))
}

// Les arguments que reçoit une commande, dans le même dessin que la ligne réécrite : arguments("Mon", "dossier") ;
// une espace dans un argument s’affiche « · », un argument vide « ∅ ».
#let arguments(taille: px(21), ..ms) = ms.pos().map(x => box(inset: (x: px(7), y: px(3)), radius: px(5), baseline: 22%,
  fill: c.fond, stroke: px(1.5) + c.encre, {
    let t = if x == "" { "∅" } else { x }
    t.split(" ").map(y => text(font: mono, size: taille, tracking: 0pt, fill: if t == "∅" { c.gris } else { c.encre }, y))
      .join(text(font: mono, size: taille, fill: c.gris, "·"))
  })).join(h(px(6)))
