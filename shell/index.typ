// Page d’accueil du cours « Fondements de l’administration système GNU/Linux » (dossier shell/) : les modules dans
// l’ordre de l’index, chacun avec ses supports. Tout est lu dans progression.yaml ; rien n’est recopié à la main.
// Un lien n’est posé que vers un support qui existe : commun/construire-site.sh passe la liste des fichiers présents
// (--input existants="cm/arbo.typ pages/arbo/ tp/premiers-pas/ …", chemins relatifs au dossier du cours). Compilée
// sans elle, la page le dit et ne pose aucun lien de support.
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     --input existants="$(cd shell && ls -d cm/*.typ pages/*/ tp/*/ artefacts/*/ | tr '\n' ' ')" shell/index.typ shell/index.html

#import "../commun/theme-tp.typ": *

#let index = yaml("progression.yaml")
#let mods = index.modules.sorted(key: m => m.ordre)
#let brut = sys.inputs.at("existants", default: none)
#let existants = if brut == none { () } else { brut.split(" ").filter(x => x != "") }
#let existe(chemin) = chemin in existants
#let noms(dossier) = existants.filter(x => x.starts-with(dossier + "/")).map(x => x.split("/").at(1))
#let etat(m, support) = m.at(support, default: (:)).at("etat", default: none)

// Les modules que l’ancien diaporama (cm/<cours>.typ) couvre encore : diapos présentes ou partielles, sans diaporama propre.
#let ancien = "cm/" + index.cours + ".typ"
#let dans-ancien = if existe(ancien) {
  mods.filter(m => etat(m, "diapos") in ("present", "partiel") and not existe("cm/" + m.id + ".typ"))
} else { () }
// « 3 à 5, 7 et 9 » : des numéros, groupés en plages.
#let plages(ns) = {
  let groupes = ()
  for n in ns {
    if groupes.len() > 0 and groupes.last().last() == n - 1 { groupes.last().push(n) } else { groupes.push((n,)) }
  }
  let textes = groupes.map(g => if g.len() == 1 { str(g.first()) } else { str(g.first()) + " à " + str(g.last()) })
  if textes.len() <= 1 { textes.join() } else { textes.slice(0, -1).join(", ") + " et " + textes.last() }
}

// Les supports d’un module, dans l’ordre diaporama, page, TP, artefact ; « à venir » pour ce que l’index prévoit.
#let a-venir(nom) = html.elem("span", attrs: (class: "a-venir"), [#nom : à venir])
#let supports(m) = {
  let liens = ()
  if existe("cm/" + m.id + ".typ") { liens.push(bouton([Diaporama], "cm/" + m.id + "-projection.pdf")) }
  else if m in dans-ancien { liens.push(html.elem("span", attrs: (class: "a-venir"), [Diapos : dans l’ancien diaporama])) }
  else if etat(m, "diapos") == "a-faire" { liens.push(a-venir[Diaporama]) }
  if existe("pages/" + m.id + "/") { liens.push(bouton(principal: true, [Page de cours], "pages/" + m.id + "/")) }
  else if etat(m, "page") in ("a-faire", "partiel") { liens.push(a-venir[Page de cours]) }
  // TP et artefacts : ceux que l’index nomme (« premiers-pas, étapes 2 et 4 ; … ») et qui existent.
  for (support, dossier, nom) in (("tp", "tp", [TP]), ("artefact", "artefacts", [Artefact])) {
    let texte = m.at(support, default: (:)).at("existant", default: "")
    let trouves = noms(dossier).filter(n => texte.split(regex("[^a-z0-9-]+")).contains(n))
    for n in trouves {
      let morceau = texte.split(" ; ").find(x => x.starts-with(n))
      liens.push(bouton([#nom : #if morceau != none { morceau } else { n }], dossier + "/" + n + "/"))
    }
    if trouves.len() == 0 and etat(m, support) == "a-faire" { liens.push(a-venir(nom)) }
  }
  actions(..liens)
}

#show: page-web.with(
  titre: [#index.titre],
  surtitre: [Cours · module par module],
  sous-titre: [#index.public],
  auteur: [Jean-Mathieu Chantrein],
  racine: "../",
  sommaire: false,
  illustration-couverture: "tube",
  liens: (([Tous les cours], "../index.html"),),
)

#if brut == none {
  note(role: "precaution")[Page compilée sans la liste des supports présents : les liens des supports sont omis
    (voir l’en-tête de `shell/index.typ`).]
}

Le cours est une suite de modules : chacun tient pour acquis ceux qui le précèdent. Chaque module s’apprend par un
diaporama, une page de cours (un terminal à côté du texte), ou les deux ; un TP l’exerce, un artefact en fait
manipuler le modèle.

#if dans-ancien.len() > 0 {
  note(role: "pratique")[Les modules #plages(dans-ancien.map(m => m.ordre)) ont encore leurs diapos dans
    l’#link("cm/" + index.cours + "-projection.pdf")[ancien diaporama du cours], en cours de découpage en un diaporama
    par module.]
}

#for m in mods {
  html.elem("section", attrs: (class: "module", id: m.id))[
    #html.elem("h2")[#html.elem("span", attrs: (class: "module-numero"))[Module #m.ordre] #m.titre]
    #if m.at("sait-faire", default: none) != none { html.elem("p", attrs: (class: "module-but"))[#eval(m.at("sait-faire"), mode: "markup")] }
    #supports(m)
  ]
}
