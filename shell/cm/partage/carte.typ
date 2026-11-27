// partage/carte.typ — la carte de progression du cours, en diapo : les modules de shell/progression.yaml (les données ne sont
// que là), leurs prérequis directs, « vous êtes ici » et ce qui est acquis. Même placement et même réduction des
// flèches que shell/carte-progression.typ (la page de travail, avec l’état des supports) ; ici, seulement ce qui sert
// à l’étudiant. Usage, dans un diaporama de cm/ : #import "partage/carte.typ": carte-progression, prog, module
//   #carte-progression(ici: "arbo")

#import "../../../commun/theme-cours.typ": *

#let prog = yaml("../../progression.yaml")
#let mods = prog.modules
#let module = mods.map(m => (m.id, m)).to-dict()

// Ancêtres : fermeture transitive de `requiert` ; flèches : les prérequis qui ne se déduisent pas d’un autre.
#let ancetres(id) = {
  let vus = ()
  let pile = module.at(id).requiert
  while pile.len() > 0 {
    let p = pile.remove(0)
    if p not in vus { vus.push(p); pile += module.at(p).requiert }
  }
  vus
}
#let directs(m) = m.requiert.filter(p => not m.requiert.any(q => q != p and p in ancetres(q)))

#let carte-progression(ici: none, etiquette: [Vous êtes ici], l: 182, h: 112, px-x: 212, px-y: 140) = {
  let acquis = if ici != none { ancetres(ici) } else { () }
  let pos(m) = (m.carte.col * px-x, 30 + m.carte.lig * px-y)
  let ncol = calc.max(..mods.map(m => m.carte.col)) + 1
  let nlig = calc.max(..mods.map(m => m.carte.lig)) + 1
  // flèches réparties le long des bords, dans l’ordre des lignes : elles ne se croisent pas en arrivant
  let entrees = mods.map(m => (m.id, directs(m).sorted(key: p => module.at(p).carte.lig))).to-dict()
  let sorties = mods.map(m => (m.id, mods.filter(n => m.id in directs(n)).map(n => n.id)
    .sorted(key: n => module.at(n).carte.lig))).to-dict()
  let point(liste, id, y0) = y0 + h * (liste.position(x => x == id) + 1) / (liste.len() + 1)
  canevas(30 + (nlig - 1) * px-y + h, {
    for m in mods {
      for p in directs(m) {
        let (xa, ya) = pos(module.at(p))
        let (xb, yb) = pos(m)
        fleche-pose(xa + l, point(sorties.at(p), m.id, ya), xb - 2, point(entrees.at(m.id), p, yb),
          couleur: c.ardoise, ep: 3, halo: c.fond)
      }
    }
    for m in mods {
      let (x, y) = pos(m)
      let est-ici = m.id == ici
      let est-acquis = m.id in acquis
      pose(x, y, box(width: px(l), height: px(h), radius: px(10), inset: (x: px(10), y: px(8)),
        fill: if est-acquis { roles.reponse.fond } else if est-ici { roles.notion.fond } else { c.fond },
        stroke: if est-ici { px(5) + c.bleu } else if est-acquis { px(2) + roles.reponse.entete } else { px(1.5) + c.filet },
        grid(columns: (auto, 1fr), column-gutter: px(8),
          pastille(m.ordre, t: px(20)),
          text(size: px(19), weight: if est-ici { 700 } else { 500 }, hyphenate: false, m.titre))))
      if est-ici {
        pose(x, y - 34, box(fill: c.bleu, radius: (top: px(8)), inset: (x: px(10), y: px(4)),
          text(size: px(20), weight: 700, fill: c.fond, etiquette)))
      }
      if est-acquis {
        pose(x + l - 70, y - 30, box(fill: roles.reponse.entete, radius: (top: px(8)), inset: (x: px(10), y: px(3)),
          text(size: px(19), weight: 700, fill: roles.reponse.texte)[acquis]))
      }
    }
  })
}
