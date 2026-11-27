// contexte.js — le repère de contexte des pages de cours (page-web(contexte: …)) : où l’on est dans l’arborescence,
// dessiné en arbre, toujours au même endroit (en tête de la colonne `.cote`, au-dessus du terminal). Deux sources :
// - réelle : en mode vm, le shell de la VM décrit avant chaque invite son répertoire courant et ce qui l’entoure
//   (vm/contexte.bash, séquence OSC 6973 que terminal.js relaie par l’événement « terminal-contexte ») ;
// - déclarée : sinon (terminal fermé, VM pas encore prête, compagnon), la page déclare l’arborescence et le répertoire
//   de départ ; le repère rejoue les `cd` des commandes de la page jusqu’au bloc qu’on lit, ou jusqu’à la dernière
//   commande cliquée dans ce bloc.
// Une commande cliquée qui lit un chemin (cd, ls, pwd, echo ~) est lue comme le shell la lit : son point de départ
// (la racine, le répertoire courant ou le répertoire personnel), puis une pastille numérotée par composant, dans
// l’arbre et dans la légende ; la conclusion se calcule d’après l’état qui suit la commande.
(() => {
  const panneau = document.querySelector(".contexte");
  const source = document.getElementById("contexte-declare");
  if (!panneau || !source) return;
  const declare = JSON.parse(source.textContent);

  // <modele> Fonctions pures : tester-vm.mjs les reprend pour comparer le contexte déclaré au contexte réel.
  const parent = p => (p === "/" ? "/" : p.replace(/\/[^/]+$/, "") || "/");
  const joindre = (p, nom) => (p === "/" ? "/" + nom : p + "/" + nom);
  const nomDe = p => (p === "/" ? "/" : p.slice(p.lastIndexOf("/") + 1));
  const ancetres = p => { const r = [p]; while (p !== "/") { p = parent(p); r.unshift(p); } return r; };
  const sous = (p, d) => p === d || p.startsWith(d === "/" ? "/" : d + "/");
  // Un état : { cwd, home, oldpwd, dossiers: { chemin: { lisible, total, entrees: [{ nom, dossier }] } } }.
  function lireRapport(texte) {
    const [entete, ...recs] = texte.split("\u241e");
    const [, cwd, home, oldpwd] = entete.split("\u241f");
    const dossiers = {};
    for (const r of recs) {
      const [chemin, total, ...noms] = r.split("\u241f");
      dossiers[chemin] = total === "-" ? { lisible: false, total: 0, entrees: [] }
        : { lisible: true, total: Number(total), entrees: noms.map(n => ({ nom: n.replace(/\/$/, ""), dossier: n.endsWith("/") })) };
    }
    return { cwd, home, oldpwd, dossiers };
  }
  // L’arborescence déclarée par la page, sans ce que créent les commandes qui ne sont pas encore passées. Un répertoire
  // dont la page ne déclare aucune entrée a un contenu inconnu (total : null) ; « chemin/. » le déclare vide.
  function dossiersDeclares(arbre, absents) {
    const dossiers = { "/": { lisible: true, total: null, entrees: [] } };
    const ajouter = (chemin, dossier) => {
      const p = parent(chemin), nom = nomDe(chemin);
      if (!dossiers[p]) ajouter(p, true);
      if (nom === ".") { dossiers[p].total ??= 0; return; }
      if (!dossiers[p].entrees.some(e => e.nom === nom)) { dossiers[p].entrees.push({ nom, dossier }); dossiers[p].total = (dossiers[p].total ?? 0) + 1; }
      if (dossier && !dossiers[chemin]) dossiers[chemin] = { lisible: true, total: null, entrees: [] };
    };
    for (const brut of arbre) {
      const chemin = brut.length > 1 ? brut.replace(/\/$/, "") : brut;
      if (chemin === "/" || absents.some(a => sous(chemin, a))) continue;
      ajouter(chemin, brut.endsWith("/"));
    }
    // L’ordre du développement des chemins de Bash en locale C.UTF-8 : celui des points de code.
    for (const d of Object.values(dossiers)) d.entrees.sort((a, b) => (a.nom < b.nom ? -1 : a.nom > b.nom ? 1 : 0));
    return dossiers;
  }
  // Lit un chemin comme le shell : un départ, puis un pas par composant (`.` reste, `..` remonte, un nom descend).
  function lireChemin(arg, etat) {
    let depart, cur, reste = arg;
    if (arg === "~" || arg.startsWith("~/")) { depart = "personnel"; cur = etat.home; reste = arg.slice(1); }
    else if (arg.startsWith("/")) { depart = "racine"; cur = "/"; }
    else { depart = "courant"; cur = etat.cwd; }
    const debut = cur, pas = [], morceaux = reste.split("/").filter(Boolean);
    for (const [i, m] of morceaux.entries()) {
      if (m === ".") { pas.push({ morceau: m, chemin: cur, sorte: "reste" }); continue; }
      if (m === "..") { cur = parent(cur); pas.push({ morceau: m, chemin: cur, sorte: "remonte" }); continue; }
      const d = etat.dossiers[cur], e = d && d.entrees.find(x => x.nom === m), suivant = joindre(cur, m);
      const complet = d && d.lisible && d.total != null && d.entrees.length >= d.total;
      if (complet && !e) { pas.push({ morceau: m, chemin: suivant, sorte: "absent" }); return { depart, debut, pas, fin: null, erreur: "absent", ou: cur }; }
      if (e && !e.dossier && i < morceaux.length - 1) { pas.push({ morceau: m, chemin: suivant, sorte: "fichier" }); return { depart, debut, pas, fin: null, erreur: "fichier", ou: cur }; }
      pas.push({ morceau: m, chemin: suivant, sorte: e && !e.dossier ? "fichier" : "descend" });
      cur = suivant;
    }
    const dernier = pas.at(-1);
    return { depart, debut, pas, fin: cur, fichier: Boolean(dernier && dernier.sorte === "fichier") };
  }
  // Ce que lit une commande : le chemin qu’elle nomme (cd, ls), le répertoire courant (pwd), ~ (echo ~).
  function lecture(commande, etat) {
    const [cmd, ...args] = commande.trim().split(/\s+/);
    const chemins = args.filter(a => !a.startsWith("-") || a === "-");
    if (cmd === "cd") {
      if (!chemins.length) return { cas: "cd-seul", depart: "personnel", debut: etat.home, pas: [], fin: etat.home };
      if (chemins[0] === "-") return { cas: "cd-moins", depart: "precedent", debut: etat.oldpwd, pas: [], fin: etat.oldpwd || null };
      return { cas: "cd", arg: chemins[0], ...lireChemin(chemins[0], etat) };
    }
    if (cmd === "ls") return chemins.length ? { cas: "ls", arg: chemins[0], ...lireChemin(chemins[0], etat) }
      : { cas: "ls-courant", depart: "courant", debut: etat.cwd, pas: [], fin: etat.cwd };
    if (cmd === "pwd") return { cas: "pwd", arg: etat.cwd, ...lireChemin(etat.cwd, etat) };
    if (cmd === "echo" && chemins.length === 1 && /^~(\/|$)/.test(chemins[0])) return { cas: "echo", arg: chemins[0], ...lireChemin(chemins[0], etat) };
    return null;
  }
  // L’état après une commande, d’après la page : seul `cd` change le répertoire courant.
  function apres(commande, etat) {
    const l = lecture(commande, etat);
    if (!l || !l.cas.startsWith("cd") || !l.fin || l.fichier || l.erreur) return etat;
    return { ...etat, oldpwd: etat.cwd, cwd: l.fin };
  }
  // Les états déclarés le long des commandes de la page : etats[i] précède la commande i, etats[n] suit la dernière.
  function etatsDeclares(contexte, commandes) {
    let absents = (contexte.creations || []).flatMap(([, chemins]) => chemins.map(c => c.replace(/(.)\/$/, "$1")));
    let etat = { cwd: contexte.depart, home: contexte.personnel || contexte.depart, oldpwd: "", dossiers: dossiersDeclares(contexte.arbre, absents) };
    const etats = [etat];
    for (const c of commandes) {
      const crees = (contexte.creations || []).filter(([prefixe]) => c.startsWith(prefixe)).flatMap(([, chemins]) => chemins.map(x => x.replace(/(.)\/$/, "$1")));
      if (crees.length) { absents = absents.filter(a => !crees.includes(a)); etat = { ...etat, dossiers: dossiersDeclares(contexte.arbre, absents) }; }
      etat = apres(c, etat);
      etats.push(etat);
    }
    return etats;
  }
  // </modele>

  // ---------- Dessin ----------
  function el(balise, attributs = {}, ...enfants) {
    const e = document.createElement(balise);
    for (const [k, v] of Object.entries(attributs)) if (v !== false && v != null) e.setAttribute(k, v === true ? "" : v);
    e.append(...enfants.filter(x => x != null && x !== false));
    return e;
  }
  const mono = texte => el("code", {}, texte);
  const pastille = (n, rang) => el("span", { class: "pastille", style: `--rang:${rang}`, "aria-hidden": "true" }, String(n));
  const etiquette = (classe, texte) => el("span", { class: "etiquette " + classe }, texte);
  const CHIPS = 24;

  // Le chemin courant en une ligne : la forme courte du repère (seule visible sur un écran étroit, repliée).
  function ligneChemin(etat) {
    const segs = etat.cwd.split("/").filter(Boolean);
    const p = el("p", { class: "contexte-chemin" }, el("span", { class: "contexte-compte" }, declare.compte || "ada"), " ");
    p.append(el("span", { class: "sep" }, "/"));
    segs.forEach((s, i) => {
      if (i) p.append(el("span", { class: "sep" }, "/"));
      p.append(i === segs.length - 1 ? el("strong", {}, s) : el("span", {}, s));
    });
    return p;
  }

  // L’arbre : la racine, le chemin jusqu’au répertoire courant et jusqu’au répertoire personnel, et ceux que la commande
  // lit. Sont dépliés (une ligne par entrée) le répertoire courant et ses ancêtres situés dans le répertoire personnel ;
  // les autres répertoires montrent leur contenu en petits noms, sur leur ligne.
  function arbre(etat, l, avant) {
    const vus = new Set([...ancetres(etat.cwd), ...ancetres(etat.home)]);
    const marques = new Map();
    const marquer = (chemin, m) => { if (!marques.has(chemin)) marques.set(chemin, []); marques.get(chemin).push(m); };
    if (l) {
      if (l.debut) { ancetres(l.debut).forEach(p => vus.add(p)); if (l.pas.length) marquer(l.debut, { depart: l.depart }); }
      l.pas.forEach((s, i) => { ancetres(s.chemin).forEach(p => vus.add(p)); marquer(s.chemin, { n: i + 1, sorte: s.sorte }); });
      if (l.fin) ancetres(l.fin).forEach(p => vus.add(p));
      if (l.fin && l.cas.startsWith("ls")) marquer(l.fin, { liste: true });
    }
    if (avant && avant !== etat.cwd) ancetres(avant).forEach(p => vus.add(p));
    const deplie = p => p === etat.cwd || (sous(etat.cwd, p) && sous(p, etat.home));
    const absents = l ? l.pas.filter(s => s.sorte === "absent") : [];

    function noeud(chemin, dossier, cache) {
      const d = etat.dossiers[chemin];
      const nom = chemin === "/" ? "/" : nomDe(chemin) + (dossier ? "/" : "");
      const li = el("li", { class: [dossier ? "n-dossier" : "n-fichier", cache ? "cache" : "", vus.has(chemin) && chemin !== etat.cwd ? "sur-chemin" : ""].join(" ").trim() });
      const ligne = el("span", { class: "ligne" });
      ligne.append(el("span", { class: "nom" + (chemin === etat.cwd ? " ici" : "") }, nom));
      if (chemin === etat.home) ligne.append(etiquette("personnel", "~"));
      for (const m of marques.get(chemin) || []) {
        if (m.depart) ligne.append(etiquette("depart", "départ"));
        else if (m.liste) ligne.append(etiquette("liste", "← listé"));
        else ligne.append(pastille(m.n, m.n));
      }
      if (chemin === etat.cwd) ligne.append(etiquette("vous-etes-ici", "◀ vous êtes ici"));
      if (avant && chemin === avant && avant !== etat.cwd) ligne.append(etiquette("avant", "avant"));
      li.append(ligne);
      if (!dossier) return li;
      if (!d) {   // contenu non décrit : seuls les répertoires du chemin dessiné y figurent
        const ul = el("ul");
        for (const p of [...vus].filter(p => p !== chemin && parent(p) === chemin).sort()) ul.append(noeud(p, true, false));
        if (ul.children.length) li.append(ul);
        return li;
      }
      if (!d.lisible) { ligne.append(el("span", { class: "resume" }, "(illisible)")); return li; }
      if (d.total == null && !d.entrees.length) return li;
      const enfants = d.entrees.map(e => ({ ...e, chemin: joindre(chemin, e.nom) }));
      const lignes = deplie(chemin) ? enfants : enfants.filter(e => vus.has(e.chemin));
      const resume = deplie(chemin) ? [] : enfants.filter(e => !vus.has(e.chemin));
      const autres = (d.total ?? d.entrees.length) - d.entrees.length;
      // Hors du répertoire personnel, un répertoire replié ne nomme son contenu que si la commande le liste.
      const nommer = sous(chemin, etat.home) || (l && l.fin === chemin && l.cas.startsWith("ls"));
      if (resume.length || autres > 0 || (!enfants.length && !absents.length)) {
        const r = el("span", { class: "resume" });
        if (!enfants.length) r.append("(vide)");
        if (!nommer && resume.length) r.append(el("span", { class: "plus" }, `… ${resume.length + Math.max(0, autres)} autres`));
        if (nommer) resume.slice(0, CHIPS).forEach(e => r.append(el("span", { class: "puce" + (e.nom.startsWith(".") ? " cache" : "") }, e.nom + (e.dossier ? "/" : "")), " "));
        const plus = Math.max(0, resume.length - CHIPS) + Math.max(0, autres);
        if (nommer && plus) r.append(el("span", { class: "plus" }, `+ ${plus}`));
        ligne.append(r);
      }
      const ul = el("ul");
      for (const e of lignes) ul.append(noeud(e.chemin, e.dossier, e.nom.startsWith(".")));
      for (const a of absents.filter(a => parent(a.chemin) === chemin)) {
        const li2 = el("li", { class: "absent" }, el("span", { class: "ligne" }, el("span", { class: "nom" }, nomDe(a.chemin)),
          pastille(l.pas.indexOf(a) + 1, l.pas.indexOf(a) + 1), etiquette("manque", "n’existe pas")));
        ul.append(li2);
      }
      if (ul.children.length) li.append(ul);
      return li;
    }
    return el("ul", { class: "arbre" }, noeud("/", true, false));
  }

  // La légende de la commande lue : son départ, ses pas, et ce qu’elle a produit (d’après l’état qui la suit).
  function legende(l, avantEtat, etat, enAttente) {
    if (!l) return null;
    const p = el("div", { class: "contexte-lecture" });
    const tete = el("p", {}, mono(l.commande), " : ");
    const nom = c => mono(c);
    if (l.cas === "cd-seul") tete.append("sans argument, retour au répertoire personnel, ", nom(l.fin), ".");
    else if (l.cas === "cd-moins") tete.append("retour au répertoire précédent, ", nom(l.fin || "?"), ", que cd affiche.");
    else if (l.cas === "ls-courant") tete.append("sans chemin, ", mono("ls"), " liste le répertoire courant, ", nom(nomDe(l.fin)), ".");
    else if (l.cas === "pwd") tete.append("le chemin absolu du répertoire courant, lu de la racine jusqu’à lui.");
    else if (l.depart === "racine") tete.append("chemin absolu, il part de la racine ", mono("/"), ".");
    else if (l.depart === "personnel") tete.append(mono("~"), " est remplacé par le répertoire personnel, ", nom(l.debut), " : le chemin devient absolu.");
    else tete.append("chemin relatif, il part du répertoire courant, ", nom(nomDe(l.debut)), ".");
    p.append(tete);
    if (l.pas.length) {
      const ol = el("ol", { class: "pas" });
      l.pas.forEach((s, i) => {
        const effet = s.sorte === "remonte" ? ["remonte dans ", mono(nomDe(s.chemin))] : s.sorte === "reste" ? ["reste dans ", mono(nomDe(s.chemin))]
          : s.sorte === "absent" ? ["n’existe pas dans ", mono(nomDe(parent(s.chemin)))] : s.sorte === "fichier" ? ["un fichier"] : ["descend"];
        ol.append(el("li", { style: `--rang:${i + 1}` }, pastille(i + 1, i + 1), mono(s.morceau), " ", el("span", { class: "effet" }, ...effet)));
      });
      p.append(ol);
    }
    // Conclusion : d’après l’état réel (ou déclaré) qui suit la commande.
    const fin = el("p", { class: "conclusion" });
    if (enAttente) fin.append("La commande s’exécute…");
    else if (l.cas.startsWith("cd")) {
      if (etat.cwd === avantEtat.cwd && l.fin !== etat.cwd) fin.append("Le répertoire courant n’a pas changé : ", mono("cd"), " a échoué, voyez son message dans le terminal.");
      else fin.append("Vous voici dans ", mono(etat.cwd), ".");
    } else if (l.cas === "ls") {
      fin.append(l.erreur || !l.fin ? "Ce chemin ne mène nulle part : ls le signale. " : "", "Vous restez dans ", mono(nomDe(etat.cwd)), " : ", mono("ls"), " ne déplace pas.");
    } else if (l.cas === "echo") fin.append(mono("echo"), " reçoit ", mono(l.fin || l.debut), " : c’est le shell qui a remplacé ", mono("~"), ".");
    if (fin.childNodes.length) p.append(fin);
    return p;
  }

  // ---------- Sources et rendu ----------
  const boutons = [...document.querySelectorAll("main .terminal:not([data-mode]) .executer")];
  const commandes = boutons.map(b => b.dataset.commande);
  const etats = etatsDeclares(declare, commandes);
  let reel = null;            // dernier état lu dans la VM
  let sessionVM = false;      // la VM est le terminal courant, session ouverte
  let session = { mode: null, ouverte: false };
  let derniere = null;        // { l, avant, avantEtat, rang, attente }
  let finAnimation = 0;
  let file = Promise.resolve(), enCours = 0;   // descriptions de la VM à appliquer ; commandes cliquées sans réponse
  const reduit = matchMedia("(prefers-reduced-motion: reduce)");

  const entete = el("div", { class: "contexte-entete" });
  const corps = el("div", { class: "contexte-corps" });
  const deplier = el("button", { type: "button", class: "contexte-deplier", "aria-expanded": "false" }, "Arbre");
  deplier.addEventListener("click", () => {
    const ouvert = panneau.classList.toggle("deplie");
    deplier.setAttribute("aria-expanded", String(ouvert));
  });
  panneau.replaceChildren(entete, corps);

  // Le bloc de commandes en cours de lecture : le dernier dont le haut a passé le tiers de la fenêtre.
  function rangLu() {
    let rang = 0;
    for (const [i, b] of boutons.entries()) {
      const bloc = b.closest(".terminal");
      if (bloc.getBoundingClientRect().top < innerHeight * 0.45) rang = i; else break;
    }
    const bloc = boutons[rang]?.closest(".terminal");
    const premier = boutons.findIndex(b => b.closest(".terminal") === bloc);
    return { bloc, premier: Math.max(0, premier) };
  }
  function etatDeclare() {
    const { bloc, premier } = rangLu();
    if (derniere && derniere.rang >= 0 && boutons[derniere.rang]?.closest(".terminal") === bloc) return { etat: etats[derniere.rang + 1], garde: true };
    return { etat: etats[premier], garde: false };
  }

  function rendre({ anime = false } = {}) {
    let etat, garde = true, texteSource;
    if (sessionVM && reel) { etat = reel; texteSource = "lu dans la VM, après la dernière commande"; }
    else {
      ({ etat, garde } = etatDeclare());
      texteSource = session.mode === "compagnon" && session.ouverte
        ? "d’après la page (la VM d’ada) : votre shell peut différer" : "d’après la page, à ce point du texte";
    }
    const l = garde && derniere ? derniere.l : null;
    entete.replaceChildren(el("span", { class: "contexte-titre" }, "Où vous êtes"), el("span", { class: "contexte-source" }, texteSource), deplier);
    const attente = derniere && derniere.attente && sessionVM;
    // La lecture de la commande avant l’arbre : elle reste en vue quand l’arbre, plus haut que le cadre, y défile.
    corps.replaceChildren(...[ligneChemin(etat), l ? legende(l, derniere.avantEtat, etat, attente) : null,
      el("div", { class: "contexte-arbre" }, arbre(etat, l, l && l.cas.startsWith("cd") && !attente ? derniere.avant : null))].filter(Boolean));
    panneau.classList.toggle("anime", anime && !reduit.matches);
    panneau.dataset.source = sessionVM && reel ? "vm" : "page";
    panneau.dataset.cwd = etat.cwd;
    // L’arbre défile dans son cadre pour garder le répertoire courant en vue.
    const cadre = corps.querySelector(".contexte-arbre"), ici = cadre.querySelector(".nom.ici");
    if (ici && cadre.scrollHeight > cadre.clientHeight) {
      const haut = ici.getBoundingClientRect().top - cadre.getBoundingClientRect().top + cadre.scrollTop;
      cadre.scrollTop = Math.max(0, haut - cadre.clientHeight / 3);
    }
  }

  document.addEventListener("terminal-session", e => {
    session = e.detail;
    const vm = e.detail.mode === "vm" && e.detail.ouverte;
    if (!vm || e.detail.reinitialise) { reel = null; enCours = 0; derniere = null; }
    sessionVM = vm;
    rendre();
  });
  // Trace la lecture de la commande cliquée sur l’état qui la précède.
  function tracer(avantEtat) {
    const l = lecture(derniere.commande, avantEtat);
    if (l) l.commande = derniere.commande;
    Object.assign(derniere, { l, avant: avantEtat.cwd, avantEtat });
    finAnimation = Date.now() + (l ? l.pas.length * 450 + 350 : 0);
    rendre({ anime: true });
  }
  document.addEventListener("terminal-commande", e => {
    const rang = boutons.indexOf(e.detail.bouton);
    const vm = sessionVM && reel;
    // attendus : les invites à passer jusqu’à celle qui suit cette commande. Une commande cliquée avant que la VM ait
    // répondu aux précédentes se lit sur l’état qu’elles laissent : on attend leurs invites pour la tracer. Une
    // commande différée (la VM démarre) part à la première invite, dont la description précède la sienne.
    if (vm && !e.detail.differee) enCours++;
    const attendus = e.detail.differee ? 2 : vm ? enCours : 1;
    derniere = { commande: e.detail.commande, rang, attente: sessionVM, attendus, l: null };
    if (attendus === 1) tracer(vm ? reel : etats[Math.max(0, rang)]);
    else rendre();
  });
  document.addEventListener("terminal-contexte", e => {
    let etat;
    try { etat = lireRapport(e.detail.texte); } catch { return; }
    // Le tracé de la commande cliquée s’achève avant que l’arbre passe à l’état qui la suit.
    // Les descriptions s’appliquent dans leur ordre d’arrivée, chacune après le tracé en cours.
    file = file.then(() => new Promise(fini => setTimeout(() => {
      reel = etat;
      if (enCours > 0) enCours--;
      // La lecture de la commande cliquée reste affichée jusqu’à l’invite suivante (une autre commande, tapée).
      if (derniere && derniere.attendus > 1) { if (--derniere.attendus === 1) tracer(reel); else rendre(); }
      else { if (derniere) { if (derniere.attente) derniere.attente = false; else derniere = null; } rendre(); }
      fini();
    }, Math.max(0, finAnimation - Date.now()))));
  });
  let planifie = false;
  addEventListener("scroll", () => {
    if (planifie || (sessionVM && reel)) return;
    planifie = true;
    requestAnimationFrame(() => { planifie = false; rendre(); });
  }, { passive: true });
  rendre();
})();
