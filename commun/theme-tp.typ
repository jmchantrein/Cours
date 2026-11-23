// theme-tp.typ — charte des pages web (travaux pratiques, page d’accueil), compilées en HTML par Typst.
// Dérive de charte.typ comme theme-cours.typ : mêmes rôles, mêmes palettes. Une page embarque toutes les
// variantes ; le lecteur choisit la sienne dans la page (tp.js), sans recompilation.
// Mise en forme : tp.css ; comportements (variante, copie des commandes, terminal) : tp.js.

#import "charte.typ": *

// Élément HTML : attributs en arguments nommés ; `data: (role: …)` donne `data-role="…"` ;
// `attrs: ("aria-hidden": "true")` pour un nom d’attribut qui n’est pas un identifiant.
#let _el(balise, corps, data: (:), attrs: (:), ..autres) = html.elem(balise,
  attrs: autres.named() + attrs + data.pairs().map(((k, v)) => ("data-" + k, v)).to-dict(), corps)

// ---------- Couleurs : une variable CSS par couleur de la charte, pour chaque variante ----------
#let _variables(v) = {
  let ch = charte-de(v)
  let lignes = ch.c.pairs().map(((k, col)) => "--c-" + k + ":" + col.to-hex())
  for (r, d) in ch.roles {
    lignes += d.pairs().map(((k, col)) => "--" + r + "-" + k + ":" + col.to-hex())
  }
  lignes.join(";")
}
// Pictogrammes des rôles, en masque CSS : ils prennent la couleur du texte qui les porte.
#let _masque(svg) = {
  let s = svg.replace(regex("<!--[^>]*-->"), "").replace("\n", " ").replace("\"", "'")
  "url(\"data:image/svg+xml," + s.replace("%", "%25").replace("#", "%23").replace("<", "%3C").replace(">", "%3E") + "\")"
}
#let _triangle = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path fill-rule='evenodd' d='M12 1 23.5 22h-23zm-1.4 7.5.5 7h1.8l.5-7zm1.4 8.4a1.4 1.4 0 1 0 0 2.8 1.4 1.4 0 0 0 0-2.8z'/></svg>"
// Pictogramme d’accessibilité (dessin propre au dépôt).
#let _pictos-acces = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='10'/><circle cx='12' cy='7' r='1' fill='black'/><path d='M7 10.5l5 1 5-1M12 11.5v4M9.5 19l2.5-3.5 2.5 3.5'/></svg>"
#let _css-charte = {
  ":root{" + _variables("projection")
  ";--picto-question:" + _masque(read("pictos/coureur.svg"))
  ";--picto-retenir:" + _masque(read("pictos/cerveau.svg"))
  ";--picto-alerte:" + _masque(_triangle)
  ";--picto-acces:" + _masque(_pictos-acces) + "}"
  palettes.keys().map(v => "[data-variante=\"" + v + "\"]{" + _variables(v) + "}").join()
}
// Le sélecteur d’accessibilité : les variantes, nommées pour qui les cherche et groupées par besoin.
#let _choix-variantes = (
  (none, (("projection", "Rendu standard"),)),
  ("Vision des couleurs", (
    ("deuteranopie", "Daltonisme : deutéranopie (rouge-vert)"),
    ("protanopie", "Daltonisme : protanopie (rouge-vert)"),
    ("tritanopie", "Daltonisme : tritanopie (bleu-jaune)"),
    ("achromatopsie", "Achromatopsie (sans couleur)"),
  )),
  ("Lecture", (("dyslexie", "Dyslexie (texte espacé)"),)),
)
#assert(_choix-variantes.map(g => g.at(1).map(o => o.at(0))).flatten().sorted() == variantes.sorted(),
  message: "le sélecteur d’accessibilité doit proposer chaque variante de charte.typ")

// Variantes regroupées par palette identique : ("projection dyslexie", "projection"), ("deuteranopie protanopie", …)…
// Un dessin (schéma, illustration) est embarqué une fois par palette ; tp.js montre celui de la variante choisie.
#let _palettes-distinctes = {
  let groupes = ()
  for v in variantes {
    let pal = repr(charte-de(v).pal)
    let i = groupes.position(g => g.at(2) == pal)
    if i == none { groupes.push((v, v, pal)) } else { groupes.at(i).at(0) += " " + v }
  }
  groupes.map(g => (g.at(0), g.at(1)))
}
#let _par-palette(dessin) = for (vs, v) in _palettes-distinctes {
  _el("div", data: (pour: vs), html.frame(dessin(charte-de(v))))
}
// Illustration de couverture d’un cours ("vm", "couches"), décorative.
#let _dessin-couverture(nom) = _el("div", class: "couverture-dessin", attrs: ("aria-hidden": "true"),
  _par-palette(ch => illustration(nom, ch.c, 0.4385pt)))

// ---------- Page ----------
// racine : chemin relatif de la page vers la racine du dépôt (polices, accueil).
// liens : paires (texte, adresse) affichées dans le bandeau.
// illustration-couverture : "vm" ou "couches", l’illustration de couverture du cours.
// sommaire : affiche le sommaire des titres `=` (en colonne à gauche sur un écran large).
// atelier : page d’artefact, compacte, qui tient sur un écran de portable sans défilement.
#let depot = "https://github.com/jmchantrein/Cours"
#let page-web(titre: none, surtitre: none, sous-titre: none, auteur: none, date: none, racine: "../../../",
  liens: (), sommaire: true, illustration-couverture: none, atelier: false, corps) = {
  let police(fichier, graisse, style) = (
    "@font-face{font-family:'IBM Plex " + (if "Mono" in fichier { "Mono" } else { "Sans" }) + "';src:url('"
    + racine + "commun/fonts/" + fichier + ".ttf');font-weight:" + graisse + ";font-style:" + style + ";font-display:swap}"
  )
  let polices = (
    police("IBMPlexSans-Regular", "400", "normal") + police("IBMPlexSans-Italic", "400", "italic")
    + police("IBMPlexSans-SemiBold", "600", "normal") + police("IBMPlexSans-Bold", "700", "normal")
    + police("IBMPlexMono-Regular", "400", "normal") + police("IBMPlexMono-SemiBold", "600", "normal")
  )
  set text(lang: "fr")
  _el("html", lang: "fr", data: (variante: "projection"))[
    #_el("head")[
      #_el("meta", none, charset: "utf-8")
      #_el("meta", none, name: "viewport", content: "width=device-width, initial-scale=1")
      #_el("title", titre)
      #_el("style", polices + _css-charte + read("tp.css"))
    ]
    #_el("body", class: if atelier { "atelier" } else if sommaire { "avec-sommaire" } else { "simple" })[
      #_el("header", class: "bandeau")[
        #_el("a", class: "accueil", href: racine + "index.html")[Cours]
        #_el("nav", liens.map(((t, a)) => _el("a", href: a, t)).join())
        #_el("label", class: "variante")[
          #_el("span", class: "variante-nom")[Accessibilité]
          #_el("select", id: "variante", title: "Rendus adaptés : daltonismes, achromatopsie, dyslexie",
            _choix-variantes.map(((groupe, options)) => {
              let o = options.map(((v, nom)) => _el("option", value: v, nom)).join()
              if groupe == none { o } else { _el("optgroup", o, label: groupe) }
            }).join())
        ]
      ]
      // En-tête : la couverture des diapos (fond nuit, surtitre, titre, illustration du cours).
      #_el("div", class: "couverture")[
        #_el("div", class: "couverture-texte")[
          #if surtitre != none { _el("p", class: "surtitre", surtitre) }
          #_el("h1", titre)
          #if sous-titre != none { _el("p", class: "sous-titre", sous-titre) }
          #if auteur != none { _el("p", class: "auteur", [#auteur#if date != none [ · #date]]) }
        ]
        #if illustration-couverture != none { _dessin-couverture(illustration-couverture) }
      ]
      #_el("div", class: "page")[
        #if sommaire { outline(title: [Sommaire], depth: 1) }
        #_el("main", corps)
      ]
      #_el("footer", class: "pied")[
        #_el("p")[
          Une erreur, une idée ?
          #_el("a", href: depot + "/issues")[Ouvrez une issue] ou proposez une pull request sur le
          #_el("a", href: depot)[dépôt] : les propositions rédigées par une IA, ou avec son aide, sont acceptées
          elles aussi.
        ]
        #_el("p")[Contenus sous licence #_el("a", href: "https://creativecommons.org/licenses/by-nc-sa/4.0/deed.fr")[CC BY-NC-SA 4.0].]
      ]
      #_el("script", read("tp.js"))
    ]
  ]
}

// ---------- Blocs ----------
// Le rôle est écrit en toutes lettres dans le bloc (sauf pour une notion) : il ne repose jamais sur la couleur seule.
#let bloc(titre, role: "notion", corps) = _el("section", class: "bloc", data: (role: role))[
  #_el("p", class: "bloc-titre")[
    #if role != "notion" { _el("span", class: "role", roles-def.at(role).nom) }
    #titre
  ]
  #corps
]
// Remarque courte, sans titre.
#let note(role: "pratique", corps) = _el("aside", class: "note", data: (role: role))[
  #if role != "notion" { _el("span", class: "role", roles-def.at(role).nom) }
  #corps
]

// ---------- Corrigés à la demande ----------
// Repliés par défaut : l’étudiant choisit de les ouvrir. L’impression de la page les omet.
#let _repli(classe, titre, corps) = _el("details", class: classe)[#_el("summary", titre)#_el("div", class: "repli", corps)]
#let indice(titre: [Indice], corps) = _repli("indice", titre, corps)
#let corrige(titre: [Corrigé], corps) = _repli("corrige", titre, corps)

// ---------- Code ----------
// Terminal : `$ ` ouvre une commande, `# ` un commentaire ; le bouton « Copier » ne copie que les commandes.
#let terminal(corps) = _el("div", class: "terminal", corps)
// Fichier réel du dépôt, affiché tel quel : `fichier("corrige/…/Dockerfile", read("corrige/…/Dockerfile"))`.
// Le corrigé montré est ainsi le fichier testé par la CI.
#let fichier(chemin, contenu, lang: auto) = {
  let nom = chemin.split("/").last()
  let langage = if lang != auto { lang } else if nom == "Dockerfile" { "dockerfile" } else if nom.ends-with(".yaml") or nom.ends-with(".yml") { "yaml" } else if nom.ends-with(".sh") { "bash" } else { none }
  _el("figure", class: "fichier")[
    #_el("figcaption")[#_el("a", href: chemin, chemin)]
    #raw(contenu.trim("\n", at: end), lang: langage, block: true)
  ]
}

// ---------- Liens vers les autres supports ----------
// Diapositive du cours magistral : `ancre` est l’étiquette posée sur son titre (`== Titre <ancre>`),
// que Typst exporte comme destination nommée du PDF.
#let diapo(pdf, ancre, corps) = _el("a", class: "diapo", href: pdf + "#nameddest=" + ancre, title: "Diapositive du cours", corps)

// ---------- Schémas ----------
// Un schéma se dessine en Typst et reçoit la charte d’une variante : `schema([légende], ch => …)`, avec
// ch.c (couleurs) et ch.roles. La page embarque un dessin par palette distincte ; tp.js montre celui de la variante choisie.
#let schema(legende, dessin) = _el("figure", class: "schema")[
  #_par-palette(ch => {
    set text(font: "IBM Plex Sans", size: 11pt, fill: encre)
    dessin(ch)
  })
  #_el("figcaption", legende)
]
// Briques de schéma : une boîte titrée (machine, réseau, conteneur) et une case (processus, volume).
#let boite(titre, fond: white, trait: encre, tirets: none, largeur: auto, corps) = rect(width: largeur, fill: fond, radius: 4pt,
  stroke: (paint: trait, thickness: 1pt, dash: tirets), inset: 7pt,
  stack(spacing: 6pt, text(size: 9pt, weight: 600, fill: trait, titre), corps))
#let case(fond: white, texte: encre, largeur: auto, corps) = rect(width: largeur, fill: fond, radius: 3pt, inset: (x: 8pt, y: 6pt),
  stroke: 0.6pt + encre, align(center, text(size: 9.5pt, fill: texte, corps)))

// ---------- Accueil : cartes et boutons ----------
// Bouton-lien ; `principal: true` pour l’action première d’une carte.
#let bouton(texte, adresse, principal: false) = _el("a", class: if principal { "bouton principal" } else { "bouton" }, href: adresse, texte)
// Carte d’un cours : son illustration de couverture, son titre, puis ses supports.
#let carte(titre, illustration: none, corps) = _el("section", class: "carte")[
  #if illustration != none { _dessin-couverture(illustration) }
  #_el("div", class: "carte-corps")[
    #_el("h2", titre)
    #corps
  ]
]
#let cartes(..c) = _el("div", class: "cartes", c.pos().join())
// Rangée de boutons.
#let actions(..b) = _el("p", class: "actions", b.pos().join())

// ---------- Artefacts ----------
// Un artefact est un petit logiciel interactif, dans <cours>/artefacts/<nom>/ : une page `<nom>.typ`
// (`page-web(atelier: true, …)`) et un script qui construit son interface dans l’élément `#artefact`.
// `#artefact(read("<nom>.js"), style: read("<nom>.css"))[aide]` : l’aide (la règle, les expériences) s’affiche
// à côté. Le style emploie les variables CSS de la charte.
#let artefact(script, style: none, aide) = {
  if style != none { _el("style", style) }
  _el("div", class: "plan-atelier")[
    #_el("div", _el("p", [Cet artefact a besoin de JavaScript.]), id: "artefact")
    #_el("aside", class: "aide", aide)
  ]
  _el("script", script)
}
// Expériences guidées : `#experiences(([question], [réponse]), …)`. tp.js en montre une à la fois.
#let experiences(..paires) = _el("div", class: "experiences", paires.pos().enumerate().map(((i, (question, reponse))) =>
  _el("section", class: "experience")[
    #_el("p", class: "experience-titre")[Expérience #(i + 1) sur #paires.pos().len()]
    #question
    #_el("details", class: "corrige")[#_el("summary")[Réponse]#_el("div", class: "repli", reponse)]
  ]).join())
