// precedence-variables.js — simulateur de « Quelle valeur gagne ? », selon le modèle du cours
// (diapos <precedence-variables>, <precedence-demo> et <precedence-groupes>) :
// - la source d'abord : un ordre fixe de niveaux (documentation, « Understanding variable precedence ») ;
//   dans l'inventaire, les fichiers group_vars se chargent par (profondeur du groupe, ansible_group_priority, nom),
//   puis host_vars : le dernier chargé gagne ;
// - un groupe enfant bat son parent ; à profondeur égale, la plus grande priorité (1 par défaut) ; à priorité
//   égale, l'ordre alphabétique ; all est le groupe de profondeur 0 ; l'hôte bat tous ses groupes ;
// - le play, le rôle, le bloc, la tâche, set_fact et -e viennent après l'inventaire, dans cet ordre.
//
// Le simulateur (la partie pure, sans DOM) est confronté au vrai Ansible par verifier-ansible.js : mêmes entrées,
// valeur vue par l'hôte et classement complet comparés (ansible-inventory --host, ansible-playbook).
// Ce qu'il ne sait pas traiter (une priorité qui n'est pas un entier), il le dit au lieu de répondre.
// Les explications sont calculées à partir du résultat de la simulation, jamais écrites d'avance.
(() => {
  // ---------- Le modèle (fonctions pures) ----------
  const HOTE = "srv1", VARIABLE = "welcome_msg";
  const GROUPES = ["bdd", "nouveaux", "prod", "web"];   // alphabétique : l'ordre des noms compte
  // Les sources hors groupes, de la plus faible à la plus forte (ordre de la documentation).
  // niveau : numéro(s) de la liste du cours ; etendue : combien d'hôtes la déclaration vise (1 hôte, 2 un groupe, 3 tous).
  const SOURCES = {
    defaults: { nom: "defaults/ du rôle", niveau: "2", rang: 2, valeur: "defaults", etendue: 3 },
    all: { nom: "group_vars/all", niveau: "3–10", rang: 3, valeur: "all", etendue: 3 },
    host: { nom: `host_vars/${HOTE}`, niveau: "3–10", rang: 3, valeur: "host_vars", etendue: 1 },
    play: { nom: "vars: du play", niveau: "12–14", rang: 12, valeur: "play", etendue: 3 },
    rolevars: { nom: "vars/ du rôle", niveau: "15", rang: 15, valeur: "role_vars", etendue: 3 },
    bloc: { nom: "vars: d’un bloc", niveau: "16–17", rang: 16, valeur: "bloc", etendue: null },
    tache: { nom: "vars: d’une tâche", niveau: "16–17", rang: 17, valeur: "tache", etendue: null },
    setfact: { nom: "set_fact", niveau: "18–21", rang: 19, valeur: "set_fact", etendue: 1 },
    extra: { nom: "-e", niveau: "22", rang: 22, valeur: "extra", etendue: 3 },
  };
  const ORDRE_SOURCES = Object.keys(SOURCES);
  const depart = () => ({
    parents: { bdd: "prod", nouveaux: "all", prod: "all", web: "prod" },   // le parc de l'exercice du cours
    membres: ["web", "nouveaux"],                                          // les groupes où srv1 est listé
    priorites: { bdd: 1, nouveaux: 1, prod: 1, web: 1 },                   // ansible_group_priority, dans l'inventaire
    fichiers: ["prod", "nouveaux"],                                        // les groupes qui ont un group_vars/<groupe>.yaml
    sources: ["defaults", "all", "host", "play"],
  });

  // Les ancêtres d'un groupe, du plus proche à all ; null si l'arbre a un cycle.
  function ancetres(parents, g) {
    const vus = [];
    for (let p = parents[g]; p !== "all"; p = parents[p]) {
      if (p === g || vus.includes(p)) return null;
      vus.push(p);
    }
    return vus;
  }
  const profondeurs = parents => Object.fromEntries(GROUPES.map(g => [g, 1 + (ancetres(parents, g)?.length ?? 0)]));
  const comparer = (a, b) => {   // compare deux clés : tableaux de nombres et de chaînes
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return { i, signe: a[i] < b[i] ? -1 : 1 };
    return { i: -1, signe: 0 };
  };
  const REGLES = ["ordre des sources", "ordre des sources", "profondeur", "priorité", "alphabet"];   // selon l'indice qui diffère

  // Simule ce que voit l'hôte. `portee` : "tout" (le playbook), ou "inventaire" (ce que décide ansible-inventory --host).
  function simuler(e, portee = "tout") {
    const r = { entree: e, valeur: null, source: null, classement: [], paires: [], groupes: [], ignores: [], contre: null,
      erreur: null, limites: [] };
    if (GROUPES.some(g => !ancetres(e.parents, g))) { r.erreur = "cycle dans l’arbre de groupes"; return r; }
    const prof = profondeurs(e.parents);
    // Les groupes où l'hôte se trouve : ceux où il est listé et leurs ancêtres.
    const actifs = new Set(e.membres.flatMap(g => [g, ...ancetres(e.parents, g)]));
    r.groupes = GROUPES.map(g => ({ nom: g, parent: e.parents[g], profondeur: prof[g], priorite: e.priorites[g],
      actif: actifs.has(g), fichier: e.fichiers.includes(g) }));
    if (r.groupes.some(g => !Number.isInteger(g.priorite))) {
      r.limites.push("une ansible_group_priority qui n’est pas un entier : le simulateur ne sait pas ce qu’Ansible en ferait");
      return r;
    }
    r.ignores = r.groupes.filter(g => g.fichier && !g.actif).map(g => g.nom);
    // Les sources présentes, chacune avec sa clé de classement : [rang, sous-rang, profondeur, priorité, nom].
    const presentes = [];
    const ajouter = (id, nom, niveau, valeur, cle, extra = {}) => presentes.push({ id, nom, niveau, valeur, cle, ...extra });
    for (const id of ORDRE_SOURCES) {
      if (!e.sources.includes(id)) continue;
      const s = SOURCES[id];
      if (portee === "inventaire" && !["all", "host"].includes(id)) continue;
      if (id === "all") ajouter(id, `${s.nom}`, s.niveau, s.valeur, [3, 1, 0, 1, "all"], { etendue: s.etendue, profondeur: 0, priorite: 1 });
      else if (id === "host") ajouter(id, s.nom, s.niveau, s.valeur, [3, 2, 0, 0, ""], { etendue: s.etendue });
      else ajouter(id, s.nom, s.niveau, s.valeur, [s.rang, 0, 0, 0, ""], { etendue: s.etendue });
    }
    for (const g of r.groupes) {
      if (g.fichier && g.actif) ajouter(`groupe:${g.nom}`, `group_vars/${g.nom}`, "3–10", g.nom, [3, 1, g.profondeur, g.priorite, g.nom],
        { etendue: 2, profondeur: g.profondeur, priorite: g.priorite, groupe: g.nom });
    }
    presentes.sort((a, b) => comparer(a.cle, b.cle).signe);
    r.classement = presentes;                                  // du plus faible au plus fort
    for (let i = 1; i < presentes.length; i++) {
      const faible = presentes[i - 1], fort = presentes[i];
      const { i: indice } = comparer(faible.cle, fort.cle);
      r.paires.push({ faible, fort, regle: REGLES[indice] });
    }
    if (presentes.length) { r.source = presentes.at(-1); r.valeur = r.source.valeur; }
    // Les contre-exemples à « le plus spécifique gagne » : une source qui vise plus d'hôtes bat une qui en vise moins.
    let pire = null;
    for (const fort of [...presentes].reverse()) {
      for (const faible of presentes) {
        if (fort.etendue == null || faible.etendue == null || faible === fort) continue;
        if (comparer(faible.cle, fort.cle).signe < 0 && fort.etendue > faible.etendue && (!pire || faible.etendue < pire.faible.etendue)) pire = { fort, faible };
      }
      if (pire) break;
    }
    r.contre = pire;
    return r;
  }

  // ---------- Explications : calculées à partir du résultat ----------
  const ETENDUES = { 1: `un seul hôte`, 2: "les hôtes d’un groupe", 3: "tous les hôtes" };
  const nomSource = s => s.nom;
  function phraseRegle(p) {
    const { faible: a, fort: b } = p;
    switch (p.regle) {
      case "ordre des sources":
        return b.id === "host"
          ? `${nomSource(b)} est chargé après ${nomSource(a)} : dans l’inventaire, l’hôte vient après tous ses groupes.`
          : `${nomSource(b)} (niveau ${b.niveau}) vient après ${nomSource(a)} (niveau ${a.niveau}) dans l’ordre fixe des sources.`;
      case "profondeur":
        return `${b.groupe ?? "all"} est à la profondeur ${b.profondeur}, ${a.groupe ?? "all"} à la profondeur ${a.profondeur} : le groupe le plus profond est chargé plus tard.`;
      case "priorité":
        return `même profondeur (${b.profondeur}) ; ansible_group_priority ${b.priorite} contre ${a.priorite} : la plus grande est chargée plus tard.`;
      default:
        return `même profondeur (${b.profondeur}) et même priorité (${b.priorite}) : ordre alphabétique, ${b.groupe} vient après ${a.groupe} et est chargé en dernier.`;
    }
  }
  function expliquer(r) {
    const p = [];
    if (r.erreur) return [`Ansible refuse cet arbre : ${r.erreur}.`];
    if (r.limites.length) return r.limites.map(l => `Limitation du simulateur : ${l}.`);
    if (!r.source) {
      p.push(`Aucune source ne définit ${VARIABLE} pour ${HOTE} : la variable est indéfinie.`);
    } else {
      p.push(`${HOTE} voit ${VARIABLE} = « ${r.valeur} » : ${nomSource(r.source)} (niveau ${r.source.niveau}) gagne, la dernière des ${r.classement.length} source${r.classement.length > 1 ? "s" : ""} présente${r.classement.length > 1 ? "s" : ""}.`);
      const dernier = r.paires.at(-1);
      if (dernier) p.push(`${nomSource(dernier.fort)} bat ${nomSource(dernier.faible)} : ${phraseRegle(dernier)}`);
      const groupes = r.classement.filter(s => s.niveau === "3–10" && s.id !== "host");
      if (groupes.length > 1) {
        p.push(`Groupes chargés du premier au dernier, par (profondeur, priorité, nom) : ${groupes.map(g => `${g.groupe ?? "all"} (${g.profondeur}, ${g.priorite})`).join(", ")}.`);
      }
    }
    for (const nom of r.ignores) p.push(`group_vars/${nom} est ignoré : ${HOTE} n’est pas dans le groupe ${nom}.`);
    if (r.contre) {
      p.push(`« Le plus spécifique gagne » est en défaut : ${nomSource(r.contre.fort)} vise ${ETENDUES[r.contre.fort.etendue]} et bat pourtant ${nomSource(r.contre.faible)}, qui vise ${ETENDUES[r.contre.faible.etendue]}.`);
    }
    return p;
  }

  // ---------- Les recettes : états à rejouer (aussi par verifier-ansible.js) ----------
  // Un état de recette : ce qui diffère du départ vide (aucune source, aucun fichier, le parc de l'exercice).
  const vide = () => ({ ...depart(), membres: [], fichiers: [], sources: [] });
  const etatDe = (changements = {}) => {
    const e = vide(), { parents, priorites, ...reste } = changements;
    return { ...e, ...reste, parents: { ...e.parents, ...parents }, priorites: { ...e.priorites, ...priorites } };
  };
  // Décrit, à partir de la différence entre deux états, ce que l'étape vient de changer.
  function decrire(avant, apres) {
    const d = [];
    const diff = (liste, nom) => {
      const ajoutes = liste(apres).filter(x => !liste(avant).includes(x)), retires = liste(avant).filter(x => !liste(apres).includes(x));
      if (ajoutes.length) d.push(`Ajouté : ${ajoutes.map(nom).join(", ")}.`);
      if (retires.length) d.push(`Retiré : ${retires.map(nom).join(", ")}.`);
    };
    diff(x => x.sources, id => `${SOURCES[id].nom}`);
    diff(x => x.fichiers, g => `group_vars/${g}`);
    diff(x => x.membres, g => `${HOTE} listé dans ${g}`);
    for (const g of GROUPES) {
      if (avant.parents[g] !== apres.parents[g]) d.push(`${g} devient enfant de ${apres.parents[g]} (avant : ${avant.parents[g]}).`);
      if (avant.priorites[g] !== apres.priorites[g]) d.push(`ansible_group_priority de ${g} : ${avant.priorites[g]} → ${apres.priorites[g]}.`);
    }
    return d;
  }
  // Les états : exportés pour que verifier-ansible.js les rejoue contre Ansible.
  const RECETTES_ETATS = {
    defaults: [
      ["Seul defaults/ du rôle déclare la variable.", { sources: ["defaults"] }],
      ["Ajouter group_vars/all.", { sources: ["defaults", "all"] }],
      ["Ajouter vars/ du rôle.", { sources: ["defaults", "all", "rolevars"] }],
    ],
    specifique: [
      ["group_vars/all et host_vars/srv1 déclarent la variable.", { sources: ["all", "host"] }],
      ["Ajouter vars: du play.", { sources: ["all", "host", "play"] }],
      ["Ajouter -e sur la ligne de commande.", { sources: ["all", "host", "play", "extra"] }],
    ],
    freres: [
      ["srv1 est dans prod et nouveaux, enfants de all, qui ont chacun un group_vars.", { membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"] }],
      ["Donner à nouveaux une ansible_group_priority de 10.", { membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"], priorites: { nouveaux: 10 } }],
      ["Donner aussi 10 à prod.", { membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"], priorites: { nouveaux: 10, prod: 10 } }],
    ],
    profondeur: [
      ["srv1 est dans web (enfant de prod) et dans nouveaux ; prod et nouveaux ont un group_vars.", { membres: ["web", "nouveaux"], fichiers: ["prod", "nouveaux"] }],
      ["Ajouter un group_vars pour web.", { membres: ["web", "nouveaux"], fichiers: ["prod", "nouveaux", "web"] }],
      ["Donner à nouveaux une ansible_group_priority de 100.", { membres: ["web", "nouveaux"], fichiers: ["prod", "nouveaux", "web"], priorites: { nouveaux: 100 } }],
      ["Faire de web un enfant direct de all.", { membres: ["web", "nouveaux"], fichiers: ["prod", "nouveaux", "web"], priorites: { nouveaux: 100 }, parents: { web: "all" } }],
    ],
    echelle: [
      ["vars: du play déclare la variable.", { sources: ["play"] }],
      ["Ajouter vars: d’un bloc.", { sources: ["play", "bloc"] }],
      ["Ajouter vars: d’une tâche.", { sources: ["play", "bloc", "tache"] }],
      ["Ajouter un set_fact avant la tâche.", { sources: ["play", "bloc", "tache", "setfact"] }],
      ["Ajouter -e sur la ligne de commande.", { sources: ["play", "bloc", "tache", "setfact", "extra"] }],
    ],
  };

  if (typeof module !== "undefined") module.exports = { simuler, expliquer, phraseRegle, depart, vide, etatDe, decrire, RECETTES_ETATS, profondeurs, ancetres, HOTE, VARIABLE, GROUPES, SOURCES, ORDRE_SOURCES };
  if (typeof document === "undefined") return;

  // ---------- Interface ----------
  const { el, bouton, recettes } = Artefact;   // création d'éléments et moteur de recettes : commun/artefact.js
  const racine = document.getElementById("artefact");
  const PAUSE = 1100;        // en ms : entre deux étapes d'une recette qui s'enchaîne sans pause
  const PHASE = 500;         // en ms : chaque moment d'une étape (commandes, classement, explication) se voit passer

  let etat = depart();
  let phase = 3;             // 0 : rien d'affiché ; 1 : la valeur et le classement ; 2 : classement et règles ; 3 : explication
  let tour = 0;              // numéro de l'étape : une étape annulée s'y reconnaît

  // ---------- Dessin des résultats ----------
  function dessinerResultats() {
    const r = simuler(etat);
    const ph = phase;
    const cadre = (cible, ...contenu) => racine.querySelector(cible).replaceChildren(...contenu);
    const pas = (texte = "…") => el("p", { class: "vide" }, texte);

    // 1. La valeur que voit l'hôte, puis le classement complet, du plus fort au plus faible, avec la règle de chaque paire voisine.
    const ordre = [...r.classement].reverse();
    cadre(".zone-resultat",
      el("h2", {}, `Ce que voit ${HOTE}`),
      ph < 1 ? pas() : r.erreur ? el("p", { class: "erreur" }, `Ansible refuse : ${r.erreur}`)
        : r.limites.length ? el("p", { class: "limite" }, "Limitation du simulateur : " + r.limites.join(" ; ") + ".")
          : el("p", { class: "valeur" }, el("code", { class: "variable" }, VARIABLE), " = ",
            r.source ? el("code", { class: "resultat" }, `"${r.valeur}"`) : el("span", { class: "indefini" }, "indéfinie"),
            ...(r.source ? [el("span", { class: "gagnante" }, ` ← ${r.source.nom}`)] : [])),
            ph < 2 ? pas() : r.erreur || r.limites.length ? pas("Pas de classement.") : !ordre.length ? pas("Aucune source présente.")
        : el("ol", { class: "classement" },
          el("li", { class: "entete" }, el("span", { class: "nom" }, "du plus fort au plus faible"), el("span", { class: "niveau" }, "niv."), el("span", { class: "regle" }, "bat la suivante par")),
          ...ordre.map((s, i) => {
          const dessous = r.paires.find(q => q.fort === s);
          return el("li", { class: "source" + (i === 0 ? " gagne" : "") },
            el("span", { class: "nom", title: `${s.nom} déclare ${VARIABLE} = "${s.valeur}"` }, el("code", {}, s.nom), ...(i === 0 ? [el("b", { class: "badge" }, "gagne")] : [])),
            el("span", { class: "niveau" }, s.niveau),
            el("span", { class: "regle" }, dessous ? dessous.regle : "(la plus faible)"));
        })));

    // 3. L'explication.
    cadre(".zone-explication",
      el("h2", {}, "Ce que dit le résultat"),
      el("div", { class: "explication-texte", role: "status", "aria-live": "polite" },
        ...(ph < 3 ? ["…"] : expliquer(r)).map(f => el("p", { class: f.startsWith("Limitation") ? "limite" : f.startsWith("Ansible refuse") ? "erreur" : "" }, f))));

    // L'arbre : la profondeur affichée est celle que le simulateur calcule.
    for (const g of r.groupes) {
      const ligne = racine.querySelector(`[data-groupe=${g.nom}]`);
      ligne.querySelector(".prof").textContent = g.profondeur;
      ligne.classList.toggle("hors", !g.actif);
      ligne.querySelector(".etat").textContent = g.actif ? "oui" : "non";
    }
  }

  // ---------- Contrôles : créés une fois, relus par `appliquer` ----------
  const modifie = () => { phase = 3; appliquer(); dessinerResultats(); aLaMain(); };
  const aLaMain = () => moteur.libre(expliquer(simuler(etat)));
  const bascule = (liste, cle, actif) => { const i = liste.indexOf(cle); if (actif && i < 0) liste.push(cle); if (!actif && i >= 0) liste.splice(i, 1); };

  function construire() {
    const ligneGroupe = g => el("tr", { "data-groupe": g },
      el("th", { scope: "row" }, el("code", {}, g)),
      el("td", {}, el("select", { "aria-label": `Parent du groupe ${g}`, "data-parent": g,
        onchange: ev => { etat.parents[g] = ev.target.value; modifie(); } },
        ...["all", ...GROUPES.filter(h => h !== g)].map(h => el("option", { value: h }, h)))),
      el("td", { class: "centre prof", "aria-label": `Profondeur de ${g}` }),
      el("td", { class: "centre" }, el("input", { type: "checkbox", "aria-label": `${HOTE} est listé dans le groupe ${g}`, "data-membre": g,
        onchange: ev => { bascule(etat.membres, g, ev.target.checked); modifie(); } })),
      el("td", { class: "centre etat" }),
      el("td", { class: "centre" }, el("input", { type: "number", step: "1", "aria-label": `ansible_group_priority de ${g}`, "data-priorite": g,
        oninput: ev => { etat.priorites[g] = ev.target.value === "" ? NaN : Number(ev.target.value); modifie(); } })),
      el("td", { class: "centre" }, el("input", { type: "checkbox", "aria-label": `group_vars/${g}.yaml déclare ${VARIABLE}`, "data-fichier": g,
        onchange: ev => { bascule(etat.fichiers, g, ev.target.checked); modifie(); } })));
    const tableau = el("table", { class: "groupes" },
      el("thead", {}, el("tr", {},
        el("th", { scope: "col" }, "groupe"), el("th", { scope: "col" }, "enfant de"), el("th", { scope: "col", title: "profondeur : all vaut 0" }, "prof."),
        el("th", { scope: "col", title: `${HOTE} est listé dans ce groupe` }, HOTE), el("th", { scope: "col", title: `${HOTE} appartient au groupe (listé, ou dans un descendant)` }, "dedans"),
        el("th", { scope: "col", title: "ansible_group_priority, écrite dans l’inventaire (1 par défaut)" }, "priorité"),
        el("th", { scope: "col", title: `group_vars/<groupe>.yaml déclare ${VARIABLE}` }, "fichier"))),
      el("tbody", {}, ...GROUPES.map(ligneGroupe)));
    const caseSource = id => el("label", { class: "source-case" },
      el("input", { type: "checkbox", "data-source": id, onchange: ev => { bascule(etat.sources, id, ev.target.checked); modifie(); } }),
      el("span", { class: "source-texte" }, el("code", {}, SOURCES[id].nom)));
    racine.replaceChildren(
      el("section", { class: "zone-groupes cadre" },
        el("div", { class: "titre-zone" }, el("h2", {}, `Groupes de ${HOTE} (all est la racine)`),
          bouton("Remettre à zéro", () => { moteur.fermer(); etat = depart(); phase = 3; appliquer(); dessinerResultats(); }, { class: "zero" })),
        tableau),
      el("section", { class: "zone-sources cadre" },
        el("h2", {}, `Où ${VARIABLE} est déclarée`),
        el("div", { class: "sources" }, ...ORDRE_SOURCES.map(caseSource))),
      el("section", { class: "zone-resultat cadre" }),
      el("section", { class: "zone-explication cadre" }));
  }
  // Remet les contrôles d'accord avec l'état, et bloque la saisie pendant une recette.
  function appliquer() {
    const fige = moteur.fige();
    for (const c of racine.querySelectorAll("[data-parent]")) {
      const g = c.dataset.parent;
      c.value = etat.parents[g];
      // Une option qui ferait un cycle est désactivée : Ansible refuse un cycle de groupes.
      for (const o of c.options) o.disabled = GROUPES.some(h => !ancetres({ ...etat.parents, [g]: o.value }, h));
    }
    for (const c of racine.querySelectorAll("[data-membre]")) c.checked = etat.membres.includes(c.dataset.membre);
    for (const c of racine.querySelectorAll("[data-fichier]")) c.checked = etat.fichiers.includes(c.dataset.fichier);
    for (const c of racine.querySelectorAll("[data-source]")) c.checked = etat.sources.includes(c.dataset.source);
    for (const c of racine.querySelectorAll("[data-priorite]")) {
      const v = etat.priorites[c.dataset.priorite];
      if (document.activeElement !== c || Number.isInteger(v)) { if (c.value !== String(v) && !(Number.isNaN(v) && c.value === "")) c.value = Number.isNaN(v) ? "" : v; }
    }
    for (const c of racine.querySelectorAll("input, select")) c.disabled = fige;
    for (const b of racine.querySelectorAll(".zero")) b.disabled = false;
  }

  // ---------- Recettes : les manipulations des expériences, jouées pas à pas ----------
  // Une action de recette règle les contrôles, laisse voir le résultat, puis rend l'explication de ce qui vient de se passer.
  const regler = changements => async () => {
    const decrits = decrire(etat, etatDe(changements));
    const moi = ++tour;
    phase = 0; etat = etatDe(changements); appliquer(); dessinerResultats();
    for (const p of [1, 2, 3]) {
      await moteur.attendre(PHASE);
      if (moi !== tour) return [];
      phase = p; dessinerResultats();
    }
    return [...(decrits.length ? [decrits.join(" ")] : []), ...expliquer(simuler(etat))];
  };
  const RECETTES = Object.fromEntries(Object.entries(RECETTES_ETATS).map(([nom, etapes]) =>
    [nom, etapes.map(([titre, changements]) => [titre, regler(changements)])]));
  // L'état de la simulation : mémorisé après chaque étape d'une recette, pour pouvoir y revenir.
  const capturer = () => structuredClone({ etat });
  function retablir(sauvegarde) {
    tour++;   // une étape en cours d'exécution est abandonnée
    etat = structuredClone(sauvegarde.etat); phase = 3;
    appliquer(); dessinerResultats();
  }
  const moteur = recettes({ recettes: RECETTES, depart: ["Départ : aucune source ne déclare la variable, srv1 n’est dans aucun groupe."],
    titreLibre: "Votre combinaison", pause: () => PAUSE,
    remettre: () => { etat = vide(); phase = 3; dessinerResultats(); }, capturer, retablir, afficher: appliquer });

  construire();
  appliquer();
  dessinerResultats();
})();
