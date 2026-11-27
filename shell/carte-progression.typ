// carte-progression.typ — la carte de progression du cours Shell, dessinée d’après progression.yaml.
// Nœuds : les modules ; flèches : les prérequis directs qui ne se déduisent pas d’un autre (réduction
// transitive) ; trois marques par nœud : diapos (D), TP (T), artefact (A).
// Compilation, depuis la racine du dépôt :
//   typst compile --root . --font-path commun/fonts shell/carte-progression.typ build/shell/carte.pdf
// « Vous êtes ici » : --input ici=<id d’un module> (le nœud est mis en valeur, l’acquis listé dessous).

#import "../commun/charte.typ": c, roles, mono, texte-sur

#let prog = yaml("progression.yaml")
#let mods = prog.modules
#let par-id = mods.map(m => (m.id, m)).to-dict()
#let ici = sys.inputs.at("ici", default: none)
#assert(ici == none or ici in par-id, message: "module inconnu : " + repr(ici))

// Ancêtres d’un module : la fermeture transitive de `requiert`.
#let ancetres(id) = {
  let vus = ()
  let pile = par-id.at(id).requiert
  while pile.len() > 0 {
    let p = pile.remove(0)
    if p not in vus { vus.push(p); pile += par-id.at(p).requiert }
  }
  vus
}
// Prérequis à dessiner : ceux qui ne sont pas déjà l’ancêtre d’un autre prérequis.
#let directs(m) = m.requiert.filter(p => not m.requiert.any(q => q != p and p in ancetres(q)))

// ---------- Mise en page ----------
#let (lb, hb) = (132pt, 92pt)          // nœud
#let (pas-x, pas-y) = (170pt, 112pt)   // pas des colonnes, des lignes
#let haut = 26pt                       // marge du haut (étiquette « vous êtes ici »)
#let ncol = calc.max(..mods.map(m => m.carte.col)) + 1
#let nlig = calc.max(..mods.map(m => m.carte.lig)) + 1
#let largeur = (ncol - 1) * pas-x + lb
#let hauteur = haut + (nlig - 1) * pas-y + hb
#let pos(m) = (m.carte.col * pas-x, haut + m.carte.lig * pas-y)

#set page(width: largeur + 48pt, height: auto, margin: 24pt, fill: c.fond)
#set text(font: "IBM Plex Sans", size: 9pt, fill: c.encre, lang: "fr")

// Marque d’un support : D, T ou A selon son état. La forme double la couleur.
#let marque(lettre, etat) = {
  let vert = roles.pratique.entete
  let l(col, barre: false) = text(size: 8pt, weight: 700, fill: col, if barre { strike(lettre) } else { lettre })
  let carre(..args, corps) = box(width: 17pt, height: 15pt, radius: 2pt, ..args, align(center + horizon, corps))
  if etat == "present" { carre(fill: vert, l(texte-sur(vert))) }
  else if etat == "partiel" {
    // moitié gauche pleine, moitié droite vide ; la lettre, sur une pastille blanche, reste lisible
    carre(fill: gradient.linear((vert, 0%), (vert, 50%), (white, 50%), (white, 100%)), stroke: 1pt + vert,
      box(fill: white, radius: 1pt, inset: (x: 1.5pt, y: 0.5pt), l(c.encre)))
  }
  else if etat == "a-faire" { carre(fill: white, stroke: (paint: c.ardoise, thickness: 1pt, dash: "dashed"), l(c.ardoise)) }
  else { carre(fill: c.espace, stroke: 0.6pt + c.filet, l(c.gris, barre: true)) }
}
// Pastille d’ordre : carré bleu, chiffre blanc (convention des schémas de la charte).
#let pastille(n) = box(width: 15pt, height: 15pt, radius: 2pt, fill: c.bleu, baseline: 25%,
  align(center + horizon, text(size: 8pt, weight: 700, fill: white, str(n))))

#let noeud(m) = {
  let fort = m.id == ici
  let role = if m.id == "intro" { roles.retenir } else { roles.notion }
  box(width: lb, height: hb, fill: role.fond, radius: 5pt, inset: (x: 7pt, y: 6pt),
    stroke: if fort { 3pt + c.bleu } else { 1pt + role.entete }, {
    grid(columns: (auto, 1fr), column-gutter: 5pt, align: (top, top),
      pastille(m.ordre),
      text(size: 9pt, weight: 600, hyphenate: false, m.titre))
    place(bottom + left, dy: -19pt, text(size: 7.5pt, fill: c.gris, raw(m.id) + [ · #m.duree min]))
    place(bottom + right, stack(dir: ltr, spacing: 3pt,
      marque("D", m.diapos.etat), marque("T", m.tp.etat), marque("A", m.artefact.etat)))
  })
}

// Flèche de a (bord droit) vers b (bord gauche). Plusieurs flèches qui arrivent sur un même nœud se
// répartissent le long de son bord gauche, dans l’ordre de leur source (de haut en bas) : elles ne se croisent pas.
#let entrees = mods.map(m => (m.id, directs(m).sorted(key: p => par-id.at(p).carte.lig))).to-dict()
#let sorties = mods.map(m => (m.id, mods.filter(n => m.id in directs(n)).map(n => n.id)
  .sorted(key: n => par-id.at(n).carte.lig))).to-dict()
#let point(liste, id, y0) = {
  let n = liste.len()
  let i = liste.position(x => x == id)
  y0 + hb * (i + 1) / (n + 1)
}
#let fleche(a, b) = {
  let (xa, ya) = pos(par-id.at(a))
  let (xb, yb) = pos(par-id.at(b))
  let depart = (xa + lb, point(sorties.at(a), b, ya))
  let arrivee = (xb - 1pt, point(entrees.at(b), a, yb))
  let (dx, dy) = (arrivee.at(0) - depart.at(0), arrivee.at(1) - depart.at(1))
  let n = calc.sqrt(calc.pow(dx / 1pt, 2) + calc.pow(dy / 1pt, 2))
  let (ux, uy) = (dx / 1pt / n, dy / 1pt / n)
  let (lt, et) = (8pt, 3.6pt)   // longueur et demi-largeur de la pointe
  let base = (arrivee.at(0) - ux * lt, arrivee.at(1) - uy * lt)
  let trait = 1.3pt + c.ardoise
  place(top + left, line(start: depart, end: base, stroke: trait))
  place(top + left, polygon(fill: c.ardoise, arrivee,
    (base.at(0) - uy * et, base.at(1) + ux * et), (base.at(0) + uy * et, base.at(1) - ux * et)))
}

// ---------- Page ----------
#text(size: 15pt, weight: 700)[Progression du cours #prog.titre]
#h(10pt) #text(fill: c.gris)[proposition d’index, à valider · #mods.len() modules · #mods.map(m => m.duree).sum() min en tout]
#v(4pt)

#box(width: largeur, height: hauteur, {
  for m in mods { for p in directs(m) { fleche(p, m.id) } }
  for m in mods {
    let (x, y) = pos(m)
    place(top + left, dx: x, dy: y, noeud(m))
    if m.id == ici {
      place(top + left, dx: x, dy: y - 19pt, box(fill: c.bleu, radius: (top: 4pt), inset: (x: 7pt, y: 4pt),
        text(size: 8pt, weight: 700, fill: white)[Vous êtes ici]))
    }
  }
})

#v(8pt)
#let legende(lettre, etat, texte) = box(inset: (right: 12pt), stack(dir: ltr, spacing: 4pt, marque(lettre, etat), align(horizon, texte)))
#text(size: 8.5pt)[
  #legende("D", "present")[présent]
  #legende("D", "partiel")[en partie, ou à remettre en ordre]
  #legende("D", "a-faire")[à faire]
  #legende("D", "sans-objet")[sans objet (raison dans l’index)]
  #h(6pt) D : diapos · T : TP · A : artefact · #pastille(0) ordre des séances proposé ·
  flèche : prérequis direct (les autres s’en déduisent)
]

#if ici != none {
  let m = par-id.at(ici)
  let acquis = mods.filter(n => n.id in ancetres(ici))
  v(6pt)
  block(width: largeur, fill: roles.question.fond, inset: 8pt, radius: 4pt)[
    #text(weight: 700)[#m.titre : ce qu’on tient pour acquis] —
    #acquis.map(n => [#n.titre (#raw(n.id))]).join[, ].
    #for q in m.ouverture [ \ #sym.arrow.r #eval(q.question, mode: "markup") #text(fill: c.gris)[→ #par-id.at(q.renvoi).titre]]
  ]
}
