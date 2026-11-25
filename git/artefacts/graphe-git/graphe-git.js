// graphe-git.js — simulateur du « graphe des commits » de Git, selon le modèle du cours
// (diapos <graphe>, <pointeurs>, <fusion>, <rebasage> et <reset-modes>, avec leurs notes) :
// - un commit désigne son ou ses parents (deux pour un commit de fusion) ; l'historique est un graphe orienté sans cycle ;
// - une branche est un pointeur vers un commit, `HEAD` désigne la branche courante ; un commit fait avancer la branche
//   courante, et elle seule ; `switch` ne déplace que `HEAD` ;
// - `merge X` : rien à faire si X est déjà un ancêtre ; avance rapide si la branche courante est un ancêtre de X ;
//   sinon un commit de fusion à deux parents ;
// - `rebase X` rejoue les commits de la branche courante au-dessus de X : de nouveaux commits, les anciens ne sont plus
//   sur aucune branche (le reflog les garde) ;
// - `reset <mode> <commit>` déplace la branche courante ; `--soft` ne touche ni l'index ni le répertoire de travail,
//   `--mixed` remet l'index, `--hard` remet l'index et le répertoire de travail.
// Pas de HEAD détachée : le cours la laisse hors de son cadre (note de la diapo « git checkout »).
// Le contenu est réduit à ce qu'il faut : chaque commit enregistre son propre fichier (A : a.txt, B : b.txt…), toujours
// avec le même contenu. Il n'y a donc jamais de conflit : un cas qui en provoquerait un n'existe pas ici. L'état d'un
// commit est l'ensemble de ses fichiers (son « arbre ») ; l'index et le répertoire de travail en sont aussi un.
// Les identifiants affichés sont des lettres, dans l'ordre de création ; ce ne sont pas des SHA.
// Cas que le simulateur ne traite pas (il le dit : « Limitation du simulateur : … ») :
// - switch, merge ou rebase quand l'index ou le répertoire diffèrent de HEAD (après reset --soft ou --mixed) ;
// - merge entre deux branches qui ont plusieurs ancêtres communs (fusion « en croix ») ;
// - rebase d'une branche qui contient un commit de fusion (Git l'aplatit) ;
// - plus de MAX_COMMITS commits.
// Le simulateur (la partie pure, sans DOM) est confronté à Git par verifier-git.js.
// Les explications sont calculées à partir du résultat de la simulation, jamais écrites d'avance.
(() => {
  // ---------- Le modèle (fonctions pures) ----------
  const MAX_COMMITS = 14;
  const BRANCHES = ["contact", "style", "faq", "titre"];   // les noms proposés ; « main » existe au départ
  const lettre = n => String.fromCharCode(65 + n);
  const fichierDe = nom => nom.toLowerCase() + ".txt";
  const tri = s => [...new Set(s)].sort();
  const memes = (a, b) => a.length === b.length && tri(a).every((x, i) => x === tri(b)[i]);
  const moins = (a, b) => a.filter(x => !b.includes(x));

  const depart = () => ({
    commits: { A: { nom: "A", parents: [], arbre: ["a.txt"], fichier: "a.txt", sur: "main" } },
    ordre: ["A"], branches: { main: "A" }, tete: "main", index: ["a.txt"], rep: ["a.txt"],
  });
  const pointe = e => e.branches[e.tete];
  const arbre = (e, c) => e.commits[c].arbre;
  const nomSuivant = e => lettre(e.ordre.length);

  // Un commit et tous ses ancêtres (lui compris).
  function ancetres(e, c) {
    const vus = new Set(), pile = [c];
    while (pile.length) { const x = pile.pop(); if (vus.has(x)) continue; vus.add(x); pile.push(...e.commits[x].parents); }
    return vus;
  }
  // Les commits qu'une branche atteint : ceux qui ne sont sur aucune branche sont « perdus » (le reflog les garde).
  function accessibles(e) {
    const tous = new Set();
    for (const t of Object.values(e.branches)) for (const c of ancetres(e, t)) tous.add(c);
    return tous;
  }
  // Les meilleurs ancêtres communs : ceux qui ne sont l'ancêtre d'aucun autre ancêtre commun.
  function basesDeFusion(e, a, b) {
    const x = ancetres(e, a), y = ancetres(e, b), communs = [...x].filter(c => y.has(c));
    return communs.filter(c => !communs.some(d => d !== c && ancetres(e, d).has(c)));
  }
  const propre = e => memes(e.index, arbre(e, pointe(e))) && memes(e.rep, e.index);

  // `git status --porcelain` : une ligne XY par fichier, d'après HEAD, l'index et le répertoire de travail.
  function statut(e) {
    const h = arbre(e, pointe(e)), lignes = [];
    for (const f of tri([...h, ...e.index, ...e.rep])) {
      const inH = h.includes(f), inI = e.index.includes(f), inW = e.rep.includes(f);
      const x = inI && !inH ? "A" : !inI && inH ? "D" : " ", y = inI && !inW ? "D" : " ";
      if (x !== " " || y !== " ") lignes.push(`${x}${y} ${f}`);
      if (inW && !inI) lignes.push(`?? ${f}`);
    }
    return lignes.sort();
  }
  // Fusion à trois points sur des ensembles de fichiers : sans conflit possible (un fichier est présent ou absent, et au
  // plus un des deux côtés a changé par rapport à la base).
  function fusionArbres(base, nous, eux) {
    return tri([...base, ...nous, ...eux]).filter(f => {
      const b = base.includes(f), o = nous.includes(f), t = eux.includes(f);
      return o === t ? o : o === b ? t : o;
    });
  }
  // Les commits à rejouer pour un rebase : ceux de la branche courante qui ne sont pas dans la cible, du plus ancien au plus récent.
  function aRejouer(e, cible) {
    const dehors = ancetres(e, cible), dedans = [...ancetres(e, pointe(e))].filter(c => !dehors.has(c));
    return { dedans, fusion: dedans.some(c => e.commits[c].parents.length > 1),
      chaine: [...dedans].sort((a, b) => e.ordre.indexOf(a) - e.ordre.indexOf(b)) };
  }

  const LIMITE_SALE = "l'index ou le répertoire de travail diffère de HEAD (reset --soft ou --mixed, ou fichiers non suivis) : Git accepterait ou refuserait selon les fichiers, le simulateur ne le calcule pas ; faites un commit, ou un reset --hard, d'abord";
  const LIMITE_PLEIN = `le simulateur gère ${MAX_COMMITS} commits au plus ; remettez à zéro`;

  // La commande telle qu'on la taperait (HEAD~n quand la cible est sur la première lignée de HEAD).
  function nommer(e, c) {
    let x = pointe(e);
    for (let n = 0; ; n++) {
      if (x === c) return n === 0 ? "HEAD" : `HEAD~${n}`;
      const p = e.commits[x].parents[0];
      if (!p) return c;
      x = p;
    }
  }
  function commande(e, op) {
    return ({
      commit: () => "git commit", branch: () => `git branch ${op.nom}`, switch: () => `git switch ${op.nom}`,
      merge: () => `git merge ${op.nom}`, rebase: () => `git rebase ${op.nom}`,
      reset: () => `git reset --${op.mode} ${e.commits[op.cible] ? nommer(e, op.cible) : op.cible}`,
    })[op.op]();
  }

  // Applique une commande ; rend le résultat (nouvel état, détails). L'état reçu n'est jamais modifié.
  //   { op: "commit" } | { op: "branch", nom } | { op: "switch", nom } | { op: "merge", nom } | { op: "rebase", nom }
  //   | { op: "reset", mode: "soft"|"mixed"|"hard", cible: <commit> }
  function appliquer(avant, op) {
    const e = structuredClone(avant), r = { op: op.op, avant, etat: avant, commande: commande(avant, op), nom: op.nom };
    const tip = pointe(e), tete = e.tete;
    const refuse = (cle, texte) => ({ ...r, [cle]: texte });
    const sale = ["switch", "merge", "rebase"].includes(op.op) && !propre(e);
    const verifierPlein = (n = 1) => e.ordre.length + n > MAX_COMMITS;
    const creer = (parents, arbreC, fichier) => {
      const nom = nomSuivant(e);
      e.commits[nom] = { nom, parents, arbre: arbreC, fichier, sur: tete };
      e.ordre.push(nom);
      return nom;
    };
    const rep0 = avant.rep;

    if (op.op === "commit") {
      if (verifierPlein()) return refuse("limite", LIMITE_PLEIN);
      const n = nomSuivant(e), f = fichierDe(n);
      e.index = tri([...e.index, f]); e.rep = tri([...e.rep, f]);
      const emporte = { ajoutes: moins(e.index, [...arbre(e, tip), f]), retires: moins(arbre(e, tip), e.index) };
      creer([tip], [...e.index], f);
      e.branches[tete] = n;
      return { ...r, etat: e, nouveau: n, parent: tip, fichier: f, emporte };
    }
    if (op.op === "branch") {
      if (e.branches[op.nom]) return refuse("erreur", `a branch named '${op.nom}' already exists`);
      e.branches[op.nom] = tip;
      return { ...r, etat: e, sur: tip };
    }
    if (op.op === "switch") {
      if (!e.branches[op.nom]) return refuse("erreur", `invalid reference: ${op.nom}`);
      if (op.nom === tete) return { ...r, etat: e, deja: true, de: tete, vers: tete, tipAvant: tip, tipApres: tip, apparus: [], disparus: [] };
      if (sale) return refuse("limite", LIMITE_SALE);
      e.tete = op.nom;
      const t = arbre(e, e.branches[op.nom]);
      e.index = [...t]; e.rep = [...t];
      return { ...r, etat: e, de: tete, vers: op.nom, tipAvant: tip, tipApres: e.branches[op.nom], apparus: moins(e.rep, rep0), disparus: moins(rep0, e.rep) };
    }
    if (op.op === "merge") {
      const cible = e.branches[op.nom];
      if (!cible) return refuse("erreur", `${op.nom} - not something we can merge`);
      if (ancetres(e, tip).has(cible)) return { ...r, etat: e, type: "a-jour", cible, tip };
      if (sale) return refuse("limite", LIMITE_SALE);
      if (ancetres(e, cible).has(tip)) {
        e.branches[tete] = cible; e.index = [...arbre(e, cible)]; e.rep = [...e.index];
        return { ...r, etat: e, type: "avance-rapide", cible, tip, apparus: moins(e.rep, rep0), disparus: moins(rep0, e.rep) };
      }
      const bases = basesDeFusion(e, tip, cible);
      if (bases.length > 1) return refuse("limite", `${bases.join(" et ")} sont deux ancêtres communs de ${tete} et ${op.nom} (fusion « en croix ») : Git doit d'abord les fusionner entre eux, le simulateur ne le calcule pas`);
      if (verifierPlein()) return refuse("limite", LIMITE_PLEIN);
      const t = fusionArbres(arbre(e, bases[0]), arbre(e, tip), arbre(e, cible));
      const n = creer([tip, cible], t, "");
      e.branches[tete] = n; e.index = [...t]; e.rep = [...t];
      return { ...r, etat: e, type: "fusion", cible, tip, nouveau: n, base: bases[0], apparus: moins(e.rep, rep0), disparus: moins(rep0, e.rep) };
    }
    if (op.op === "rebase") {
      const cible = e.branches[op.nom];
      if (!cible) return refuse("erreur", `invalid upstream '${op.nom}'`);
      if (sale) return refuse("limite", LIMITE_SALE);   // Git refuse de rebaser avec des changements, même s'il n'y a rien à rejouer
      const { chaine, fusion } = aRejouer(e, cible);
      // Même « à jour », Git réécrit une branche dont l'historique depuis la cible contient une fusion (il l'aplatit).
      if (fusion) return refuse("limite", `${tete} contient un commit de fusion : Git l'aplatit en rejouant ses commits, le simulateur ne le calcule pas`);
      if (ancetres(e, tip).has(cible)) return { ...r, etat: e, type: "a-jour", cible, tip };
      if (ancetres(e, cible).has(tip)) {
        e.branches[tete] = cible; e.index = [...arbre(e, cible)]; e.rep = [...e.index];
        return { ...r, etat: e, type: "avance-rapide", cible, tip, apparus: moins(e.rep, rep0), disparus: moins(rep0, e.rep) };
      }
      let courant = cible, arbreC = arbre(e, cible);
      const copies = [], ignores = [];
      for (const c of chaine) {
        const cm = e.commits[c], res = fusionArbres(arbre(e, cm.parents[0]), arbreC, cm.arbre);
        if (memes(res, arbreC)) { ignores.push(c); continue; }
        if (verifierPlein()) return refuse("limite", LIMITE_PLEIN);
        const n = creer([courant], res, cm.fichier);
        copies.push({ ancien: c, nouveau: n });
        courant = n; arbreC = res;
      }
      e.branches[tete] = courant; e.index = [...arbreC]; e.rep = [...arbreC];
      const perdus = chaine.filter(c => !accessibles(e).has(c));
      return { ...r, etat: e, type: copies.length ? "rejeu" : "avance-rapide", cible, tip, copies, ignores, perdus, chaine,
        apparus: moins(e.rep, rep0), disparus: moins(rep0, e.rep) };
    }
    if (op.op === "reset") {
      if (!e.commits[op.cible]) return refuse("erreur", `ambiguous argument '${op.cible}': unknown revision`);
      const cible = op.cible, a0 = ancetres(e, tip), a1 = ancetres(e, cible);
      const relation = cible === tip ? "meme" : a0.has(cible) ? "recule" : a1.has(tip) ? "avance" : "ailleurs";
      const defaits = [...a0].filter(c => !a1.has(c)).sort((x, y) => e.ordre.indexOf(x) - e.ordre.indexOf(y));
      const indexAvant = avant.index, t = arbre(e, cible);
      e.branches[tete] = cible;
      if (op.mode !== "soft") e.index = [...t];
      if (op.mode === "hard") e.rep = tri([...e.rep.filter(f => !indexAvant.includes(f)), ...t]);
      const perdus = defaits.filter(c => !accessibles(e).has(c));
      return { ...r, etat: e, mode: op.mode, cible, tip, relation, defaits, perdus, statut: statut(e),
        indexChange: !memes(indexAvant, e.index), repChange: !memes(rep0, e.rep),
        efface: moins(rep0, e.rep), gardesIndex: moins(e.index, t), gardesRep: moins(e.rep, e.index),
        retablis: moins(e.rep, rep0) };
    }
    throw new Error(`commande inconnue : ${op.op}`);
  }

  // ---------- Explications (calculées à partir du résultat) ----------
  const s = (n, mot) => `${n} ${mot}${n > 1 ? "s" : ""}`;
  const liste = xs => xs.length < 2 ? xs.join("") : `${xs.slice(0, -1).join(", ")} et ${xs[xs.length - 1]}`;
  const autresBranches = e => Object.entries(e.branches).filter(([n]) => n !== e.tete);
  const ou = (e, [n, c]) => `${n} (${c})`;

  function expliquer(r) {
    const p = [`$ ${r.commande}`];
    if (r.erreur) { p.push(`Impossible : Git refuse (« ${r.erreur} »).`); return p; }
    if (r.limite) { p.push(`Limitation du simulateur : ${r.limite}.`); return p; }
    const e = r.etat, tete = e.tete, av = r.avant;
    if (r.op === "commit") {
      p.push(`${r.nouveau} est créé : son parent est ${r.parent}, et il enregistre le fichier ${r.fichier}.`);
      const autres = autresBranches(e);
      p.push(`${tete} avance de ${r.parent} à ${r.nouveau}, et elle seule ; HEAD la suit.${autres.length ? ` ${liste(autres.map(a => ou(e, a)))} ${autres.length > 1 ? "restent" : "reste"} en place.` : ""}`);
      if (r.emporte.ajoutes.length) p.push(`Le commit emporte aussi ${liste(r.emporte.ajoutes)}, déjà ${r.emporte.ajoutes.length > 1 ? "indexés" : "indexé"}.`);
    } else if (r.op === "branch") {
      p.push(`La branche ${r.nom} est créée sur ${r.sur} : un pointeur de plus, aucun commit nouveau.`);
      p.push(`HEAD reste sur ${tete} : on ne change de branche qu'avec switch.`);
    } else if (r.op === "switch") {
      if (r.deja) { p.push(`HEAD est déjà sur ${r.vers} : rien ne bouge.`); return p; }
      p.push(`HEAD quitte ${r.de} (${r.tipAvant}) pour ${r.vers} (${r.tipApres}) : seul HEAD se déplace, aucun commit n'est créé.`);
      const d = [r.apparus.length ? `${liste(r.apparus)} ${r.apparus.length > 1 ? "apparaissent" : "apparaît"}` : "", r.disparus.length ? `${liste(r.disparus)} ${r.disparus.length > 1 ? "disparaissent" : "disparaît"}` : ""].filter(Boolean);
      p.push(d.length ? `Le répertoire de travail reçoit les fichiers de ${r.tipApres} : ${d.join(", ")} du disque, pas du dépôt.` : `Le répertoire de travail ne change pas : ${r.tipApres} a les mêmes fichiers que ${r.tipAvant}.`);
    } else if (r.op === "merge") {
      if (r.type === "a-jour") p.push(`Already up to date : ${r.nom} (${r.cible}) est déjà un ancêtre de ${tete} (${r.tip}) — ou le même commit : il n'y a rien à fusionner, rien ne bouge.`);
      else if (r.type === "avance-rapide") {
        p.push(`Avance rapide : ${tete} (${r.tip}) est un ancêtre de ${r.nom} (${r.cible}), il n'y a rien à combiner.`);
        p.push(`${tete} avance jusqu'à ${r.cible}, sans nouveau commit ; HEAD la suit.${r.apparus.length ? ` ${liste(r.apparus)} ${r.apparus.length > 1 ? "apparaissent" : "apparaît"} dans le répertoire.` : ""}`);
      } else {
        p.push(`Commit de fusion : ${tete} (${r.tip}) et ${r.nom} (${r.cible}) ont chacun des commits que l'autre n'a pas, depuis leur ancêtre commun ${r.base}.`);
        p.push(`Git combine les changements des deux côtés dans ${r.nouveau}, qui a deux parents : ${r.tip} puis ${r.cible}. ${tete} avance à ${r.nouveau} ; ${r.nom} n'a pas bougé. Pas de conflit : chaque commit a touché son propre fichier${r.apparus.length ? ` (${liste(r.apparus)} ${r.apparus.length > 1 ? "arrivent" : "arrive"} dans le répertoire)` : ""}.`);
      }
    } else if (r.op === "rebase") {
      if (r.type === "a-jour") p.push(`Current branch ${tete} is up to date : ${r.nom} (${r.cible}) est déjà un ancêtre de ${tete} (${r.tip}), il n'y a rien à rejouer.`);
      else if (r.type === "avance-rapide") {
        p.push(r.ignores?.length
          ? `Les commits de ${tete} (${liste(r.ignores)}) ont déjà leur équivalent dans ${r.nom} : Git les ignore.`
          : `${tete} (${r.tip}) est un ancêtre de ${r.nom} (${r.cible}) : il n'y a rien à rejouer.`);
        p.push(`${tete} avance jusqu'à ${r.cible} (avance rapide), sans nouveau commit.`);
      } else {
        const k = r.chaine.length;
        p.push(`git rebase rejoue ${s(k, "commit")} de ${tete} (${liste(r.chaine)}) au-dessus de ${r.nom} (${r.cible}) : ${r.copies.map(c => `${c.ancien} devient ${c.nouveau}`).join(" ; ")}. Même changement, autre parent, donc ${r.copies.length > 1 ? "de nouveaux identifiants" : "un nouvel identifiant"}.`);
        if (r.ignores.length) p.push(`${liste(r.ignores)} ${r.ignores.length > 1 ? "sont ignorés" : "est ignoré"} : ${r.ignores.length > 1 ? "leur changement est" : "son changement est"} déjà dans ${r.nom}.`);
        p.push(`${tete} pointe maintenant sur ${e.branches[tete]}.${r.perdus.length ? ` ${liste(r.perdus)} ${r.perdus.length > 1 ? "ne sont plus" : "n'est plus"} sur aucune branche (en tirets) ; git reflog ${r.perdus.length > 1 ? "les retrouve" : "le retrouve"}.` : ` Les anciens commits restent accessibles par une autre branche.`}`);
      }
    } else if (r.op === "reset") {
      const rel = { meme: `${r.cible} est déjà le commit courant : la branche ne bouge pas`, recule: `${tete} recule de ${r.tip} à ${r.cible} (${s(r.defaits.length, "commit")} défait${r.defaits.length > 1 ? "s" : ""})`,
        avance: `${tete} avance de ${r.tip} à ${r.cible}`, ailleurs: `${tete} saute de ${r.tip} à ${r.cible}, sur une autre ligne d'histoire` }[r.relation];
      p.push(`${rel} ; HEAD la suit.${r.defaits.length && r.perdus.length ? ` ${liste(r.perdus)} ${r.perdus.length > 1 ? "ne sont plus" : "n'est plus"} sur aucune branche (en tirets) ; git reflog ${r.perdus.length > 1 ? "les retrouve" : "le retrouve"}.` : ""}`);
      if (r.mode === "soft") {
        p.push(`--soft ne touche ni l'index ni le répertoire de travail. ${r.gardesIndex.length ? `Les changements défaits (${liste(r.gardesIndex)}) restent indexés : prêts pour un nouveau commit.` : `Rien de plus à garder : l'index contient déjà exactement ${r.cible}.`}`);
      } else if (r.mode === "mixed") {
        p.push(`--mixed (le mode par défaut) remet l'index à ${r.cible} ; le répertoire de travail ne change pas. ${r.gardesRep.length ? `${liste(r.gardesRep)} ${r.gardesRep.length > 1 ? "restent" : "reste"} dans le répertoire, mais ${r.gardesRep.length > 1 ? "ne sont plus indexés" : "n'est plus indexé"} (non suivi${r.gardesRep.length > 1 ? "s" : ""}).` : r.indexChange ? "Aucun fichier à garder hors de l'index." : "L'index était déjà à " + r.cible + " : rien ne change."}`);
      } else {
        p.push(`--hard remet l'index et le répertoire de travail à ${r.cible}.`);
        // un fichier effacé reste dans les commits qui le contiennent ; seul un fichier jamais enregistré est perdu
        const enregistres = r.efface.filter(f => e.ordre.some(c => arbre(e, c).includes(f))), jamais = moins(r.efface, enregistres);
        if (enregistres.length) p.push(`${liste(enregistres)} ${enregistres.length > 1 ? "sont effacés" : "est effacé"} du répertoire ; ${enregistres.length > 1 ? "ils restent" : "il reste"} dans ${enregistres.length > 1 ? "leurs commits" : "son commit"} ${liste(e.ordre.filter(c => enregistres.some(f => arbre(e, c).includes(f))))}, que git reflog retrouve.`);
        if (jamais.length) p.push(`Danger : ${liste(jamais)} ${jamais.length > 1 ? "sont effacés" : "est effacé"} du répertoire et ${jamais.length > 1 ? "n'étaient" : "n'était"} dans aucun commit : perdu${jamais.length > 1 ? "s" : ""} pour de bon.`);
        if (r.retablis.length) p.push(`${liste(r.retablis)} ${r.retablis.length > 1 ? "réapparaissent" : "réapparaît"} dans le répertoire.`);
        if (r.gardesRep.length) p.push(`${liste(r.gardesRep)} ${r.gardesRep.length > 1 ? "restent" : "reste"} : Git ne ${r.gardesRep.length > 1 ? "les" : "le"} suit pas, reset --hard n'y touche pas.`);
        if (!r.efface.length && !r.retablis.length && !r.gardesRep.length && !r.indexChange) p.push(`Index et répertoire étaient déjà à ${r.cible} : rien ne change.`);
      }
      p.push(r.statut.length ? `git status --porcelain : ${r.statut.join(" ; ")}.` : `git status --porcelain : rien (index et répertoire = HEAD).`);
    }
    return p;
  }

  // ---------- Scénarios des recettes (partagés avec le vérificateur) ----------
  const c = { op: "commit" }, br = nom => ({ op: "branch", nom }), sw = nom => ({ op: "switch", nom }), mg = nom => ({ op: "merge", nom }), rb = nom => ({ op: "rebase", nom });
  const rs = (mode, cible) => ({ op: "reset", mode, cible });
  // Chaque étape : [titre, opérations]. `cible` d'un reset est un nom de commit (ou une fonction de l'état).
  const SCENARIOS = {
    "pointeurs": [
      ["Faire un commit sur main.", [c]],
      ["Créer la branche contact, puis s'y placer.", [br("contact"), sw("contact")]],
      ["Faire un commit sur contact.", [c]],
      ["Revenir sur main et y faire un commit.", [sw("main"), c]],
    ],
    "avance-rapide": [
      ["Faire un commit sur main.", [c]],
      ["Créer la branche contact et s'y placer.", [br("contact"), sw("contact")]],
      ["Faire un commit sur contact.", [c]],
      ["Revenir sur main.", [sw("main")]],
      ["Fusionner contact dans main.", [mg("contact")]],
    ],
    "fusion": [
      ["Faire un commit sur main.", [c]],
      ["Créer la branche style et s'y placer.", [br("style"), sw("style")]],
      ["Faire un commit sur style.", [c]],
      ["Revenir sur main et y faire un commit.", [sw("main"), c]],
      ["Fusionner style dans main.", [mg("style")]],
      ["Relancer la même fusion.", [mg("style")]],
    ],
    "rebasage": [
      ["Créer la branche faq, s'y placer et y faire deux commits.", [br("faq"), sw("faq"), c, c]],
      ["Revenir sur main et y faire un commit.", [sw("main"), c]],
      ["Se placer sur faq et la rebaser sur main.", [sw("faq"), rb("main")]],
      ["Revenir sur main et fusionner faq.", [sw("main"), mg("faq")]],
    ],
    "reset": [
      ["Faire un commit « Brouillon » sur main.", [c]],
      ["reset --soft HEAD~1.", [rs("soft", "A")]],
      ["Revenir au commit défait par reset --hard (retrouvé par git reflog).", [rs("hard", "B")]],
      ["reset --mixed HEAD~1.", [rs("mixed", "A")]],
      ["Revenir de nouveau au commit défait par reset --hard.", [rs("hard", "B")]],
      ["reset --hard HEAD~1.", [rs("hard", "A")]],
    ],
  };

  if (typeof module !== "undefined") module.exports = { memes, depart, appliquer, expliquer, statut, propre, accessibles, ancetres, pointe, arbre, basesDeFusion, commande, nommer, SCENARIOS, MAX_COMMITS, BRANCHES, fichierDe, tri };
  if (typeof document === "undefined") return;

  // ---------- Interface ----------
  const { el, bouton, recettes } = Artefact;   // création d'éléments et moteur de recettes : commun/artefact.js
  const racine = document.getElementById("artefact");
  const NS = "http://www.w3.org/2000/svg";
  const sv = (balise, attributs = {}, ...enfants) => {
    const x = document.createElementNS(NS, balise);
    for (const [k, v] of Object.entries(attributs)) if (v !== false && v != null) x.setAttribute(k, v);
    x.append(...enfants);
    return x;
  };
  const PHASE = 450;         // en ms : le graphe change d'abord, l'explication vient ensuite
  const PAUSE = 1100;        // en ms : entre deux étapes d'une recette qui s'enchaîne sans pause

  let sim = depart();
  let choix = { branche: "contact", vers: "", fusion: "", rebase: "", mode: "mixed", cible: "A" };
  let derniere = [];         // les phrases de la dernière commande
  let signal = new Set();    // commits et pointeurs que la dernière commande vient de changer (« A », « branche:main », « HEAD »)
  let phase = 2;             // 1 : le graphe ; 2 : l'explication
  let tour = 0;              // numéro de la commande : une commande abandonnée s'y reconnaît

  // ---------- Dessin du graphe ----------
  // Colonnes : l'ordre de création (de gauche à droite, les parents avant les enfants). Voies : une par ligne d'histoire,
  // main en bas ; un commit prend la voie de sa branche, ou la première où le trait vers son parent ne traverse rien.
  const L = 46, H = 28, ECART = 62, HAUT_VOIE = 84, PILULE = 19;
  function disposition(e) {
    const col = {}, voie = {}, voiesBranche = { main: 0 }, derniers = {};
    e.ordre.forEach((n, i) => {
      col[n] = i;
      const cm = e.commits[n];
      if (!(cm.sur in voiesBranche)) voiesBranche[cm.sur] = Object.keys(voiesBranche).length;
      const p = cm.parents[0];
      const libre = v => !e.ordre.slice(0, i).some(q => voie[q] === v && p !== undefined && col[q] > col[p] && q !== p);
      let v = voiesBranche[cm.sur];
      if (p === undefined) v = 0;
      else if (!libre(v)) { v = 0; while (!libre(v)) v++; }
      voie[n] = v;
    });
    return { col, voie, nVoies: Math.max(...Object.values(voie)) + 1 };
  }
  const couleurCommit = cm => cm.sur === "main" ? "var(--c-bleu)" : "var(--c-branche)";
  const texteCommit = cm => cm.sur === "main" ? "var(--c-fond)" : "var(--c-encre)";

  function etiquette(x, y, texte, genre, signale) {
    const lg = Math.max(texte.length * 7 + 14, 34);
    const fond = genre === "head" ? { fill: "var(--c-fond)", stroke: "var(--c-encre)", "stroke-width": 2 } : { fill: "var(--c-nuit)" };
    return sv("g", { class: `pointeur${signale ? " signale" : ""}`, "data-pointeur": texte },
      sv("rect", { x: x - lg / 2, y: y - PILULE / 2, width: lg, height: PILULE, rx: 5, ...fond }),
      sv("text", { x, y: y + 4, "text-anchor": "middle", class: "etiquette", fill: genre === "head" ? "var(--c-encre)" : "var(--c-fond)" }, texte));
  }
  function dessinerGraphe() {
    const e = sim, { col, voie, nVoies } = disposition(e), acc = accessibles(e), tip = pointe(e);
    const X = n => 40 + col[n] * ECART, Y = n => (nVoies - 1 - voie[n]) * HAUT_VOIE;
    const enfants = [];
    // les commits sous chaque pointeur
    const parCommit = {};
    for (const [nom, cmt] of Object.entries(e.branches)) (parCommit[cmt] ??= []).push(nom);
    const aretes = [], noeuds = [], pointeurs = [];
    let haut = Infinity, bas = -Infinity;   // l'étendue verticale réelle du dessin
    for (const n of e.ordre) {
      const cm = e.commits[n], perdu = !acc.has(n);
      haut = Math.min(haut, Y(n) - H / 2 - 2); bas = Math.max(bas, Y(n) + H / 2 + 2);
      cm.parents.forEach((p, i) => {
        const x1 = X(n) - L / 2, y1 = Y(n), x2 = X(p) + L / 2, y2 = Y(p), m = (x1 + x2) / 2;
        const d = y1 === y2 ? `M${x1} ${y1} L${x2 + 1} ${y2}` : `M${x1} ${y1} C${m} ${y1} ${m} ${y2} ${x2 + 1} ${y2}`;
        aretes.push(sv("path", { d, class: `arete${perdu ? " perdue" : ""}${i ? " seconde" : ""}`, "marker-end": "url(#fleche)" }));
      });
      noeuds.push(sv("g", { class: `commit${perdu ? " perdu" : ""}${signal.has(n) ? " signale" : ""}`, "data-commit": n, tabindex: -1,
        "aria-label": `commit ${n}${cm.parents.length ? `, parent${cm.parents.length > 1 ? "s" : ""} ${cm.parents.join(" et ")}` : ", sans parent"}, créé sur ${cm.sur}${perdu ? ", sur aucune branche" : ""}` },
        sv("title", {}, `${n} · créé sur ${cm.sur}${perdu ? " · sur aucune branche (git reflog le retrouve)" : ""}`),
        sv("rect", { x: X(n) - L / 2, y: Y(n) - H / 2, width: L, height: H, rx: H / 2, fill: perdu ? "none" : couleurCommit(cm), class: "pilule" }),
        sv("text", { x: X(n), y: Y(n) + 5, "text-anchor": "middle", class: "id", fill: perdu ? "var(--c-gris)" : texteCommit(cm) }, n)));
    }
    // pointeurs : au-dessus, la branche courante puis HEAD ; au-dessous, les autres branches (un trait commun les relie au commit)
    for (const [n, noms] of Object.entries(parCommit)) {
      const cx = X(n), cy = Y(n), courante = noms.includes(e.tete), autres = noms.filter(b => b !== e.tete);
      const dessus = [];
      if (courante) dessus.push([e.tete, "branche"], ["HEAD", "head"]);
      if (dessus.length) haut = Math.min(haut, cy - H / 2 - 9 - dessus.length * (PILULE + 9) + 4);
      dessus.forEach(([t, g], i) => {
        const y = cy - H / 2 - 9 - PILULE / 2 - i * (PILULE + 9);
        pointeurs.push(sv("line", { x1: cx, y1: y + PILULE / 2, x2: cx, y2: i === 0 ? cy - H / 2 - 1 : y + PILULE / 2 + 9 - 1, class: "trait-pointeur", "marker-end": "url(#fleche-p)" }));
        pointeurs.push(etiquette(cx, y, t, g, signal.has(g === "head" ? "HEAD" : `branche:${t}`)));
      });
      if (autres.length) {
        bas = Math.max(bas, cy + H / 2 + 9 + autres.length * (PILULE + 4) + 2);
        const fin = cy + H / 2 + 9 + autres.length * (PILULE + 4);
        pointeurs.push(sv("line", { x1: cx, y1: fin - PILULE / 2, x2: cx, y2: cy + H / 2 + 1, class: "trait-pointeur", "marker-end": "url(#fleche-p)" }));
        autres.forEach((t, i) => pointeurs.push(etiquette(cx, cy + H / 2 + 9 + PILULE / 2 + i * (PILULE + 4), t, "branche", signal.has(`branche:${t}`))));
      }
    }
    const largeur = 40 * 2 + (e.ordre.length - 1) * ECART + L, hautVue = bas - haut;
    const svg = sv("svg", { viewBox: `0 ${haut} ${largeur} ${hautVue}`, class: "graphe", role: "img", "data-largeur": largeur, "data-hauteur": hautVue,
      "aria-label": `Graphe des commits : ${e.ordre.map(n => `${n}${e.commits[n].parents.length ? ` → ${e.commits[n].parents.join(" et ")}` : ""}`).join(" ; ")}. ${Object.entries(e.branches).map(([b, cmt]) => `${b} → ${cmt}`).join(", ")}, HEAD → ${e.tete}.` },
      sv("defs", {},
        sv("marker", { id: "fleche", viewBox: "0 0 10 10", refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: "auto" }, sv("path", { d: "M0 0 L10 5 L0 10 z", fill: "var(--c-gris)" })),
        sv("marker", { id: "fleche-p", viewBox: "0 0 10 10", refX: 9, refY: 5, markerWidth: 6, markerHeight: 6, orient: "auto" }, sv("path", { d: "M0 0 L10 5 L0 10 z", fill: "var(--c-encre)" }))),
      ...aretes, ...pointeurs, ...noeuds);
    return svg;
  }
  // Le graphe prend la place disponible, sans jamais grossir de plus de 30 % (un graphe d'un commit reste modeste).
  function ajuster() {
    const zone = racine.querySelector(".zone-graphe .toile"), svg = zone?.querySelector("svg");
    if (!svg) return;
    const l = +svg.dataset.largeur, h = +svg.dataset.hauteur, k = Math.min(1.3, zone.clientWidth / l, zone.clientHeight / h);
    svg.style.width = `${Math.floor(l * k)}px`; svg.style.height = `${Math.floor(h * k)}px`;
  }

  // ---------- Dessin des zones et de l'explication ----------
  function puces(fichiers, de) {
    return fichiers.length ? fichiers.map(f => el("span", { class: `puce${de && !de.includes(f) ? " nouvelle" : ""}` }, f)) : [el("span", { class: "vide" }, "(rien)")];
  }
  // Index et répertoire s'écrivent « = HEAD » ou « = index » quand ils n'en diffèrent pas ; sinon, leurs fichiers.
  function dessinerZones() {
    const e = sim, t = arbre(e, pointe(e)), st = statut(e);
    const ligne = (nom, contenu) => [el("span", { class: "zone-nom" }, nom), el("span", { class: "puces" }, ...contenu)];
    racine.querySelector(".zones").replaceChildren(
      ...ligne(`HEAD (${pointe(e)})`, puces(t)),
      ...ligne("Index", memes(e.index, t) ? [el("span", { class: "egal" }, "= HEAD")] : puces(e.index, t)),
      ...ligne("Répertoire", memes(e.rep, e.index) ? [el("span", { class: "egal" }, "= index")] : puces(e.rep, e.index)),
      el("span", { class: "zone-nom" }, el("code", {}, "status")), el("div", { class: "statut" }, st.length ? st.join("\n") : "(rien : propre)"));
  }
  const classePhrase = f => /^(Danger|Défaut|Impossible)/.test(f) ? "danger" : f.startsWith("Limitation") ? "limite" : f.startsWith("$ ") ? "cmd" : "";
  function dessinerExplication() {
    racine.querySelector(".explication-texte").replaceChildren(...(phase < 2 ? ["…"] : derniere).map(f =>
      el("p", { class: classePhrase(f) }, f.startsWith("$ ") ? el("code", {}, f) : f)));
  }
  const optionsDe = (liste, vide) => liste.length ? liste.map(x => el("option", { value: x }, x)) : [el("option", { value: "" }, vide)];
  function relatifs(e) {
    // « HEAD~n » pour la première lignée de HEAD, sinon le nom de la branche, sinon « perdu ».
    const acc = accessibles(e), out = [];
    for (const n of [...e.ordre].reverse()) {
      const nom = nommer(e, n), branches = Object.entries(e.branches).filter(([, cmt]) => cmt === n).map(([b]) => b);
      const et = [nom !== n ? nom : "", ...branches.filter(b => b !== e.tete || nom === n)].filter(Boolean);
      out.push([n, et.length ? `${n} (${et.join(", ")})` : acc.has(n) ? n : `${n} (perdu : reflog)`]);
    }
    return out;
  }
  function dessiner() {
    const e = sim, fige = moteur.fige(), plein = e.ordre.length >= MAX_COMMITS;
    const libres = BRANCHES.filter(b => !e.branches[b]), autres = Object.keys(e.branches).filter(b => b !== e.tete);
    const reglerMenu = (cle, valeurs, cleChoix) => {
      const m = racine.querySelector(`[data-cle=${cle}]`);
      m.replaceChildren(...valeurs.map(([v, t]) => el("option", { value: v }, t)));
      if (!valeurs.some(([v]) => v === choix[cleChoix])) choix[cleChoix] = valeurs[0]?.[0] ?? "";
      m.value = choix[cleChoix]; m.disabled = fige || !valeurs.length;
    };
    reglerMenu("branche", libres.map(b => [b, b]), "branche");
    reglerMenu("vers", autres.map(b => [b, b]), "vers");
    reglerMenu("fusion", autres.map(b => [b, b]), "fusion");
    reglerMenu("rebase", autres.map(b => [b, b]), "rebase");
    const rel = relatifs(e);
    const m = racine.querySelector("[data-cle=cible]");
    m.replaceChildren(...rel.map(([v, t]) => el("option", { value: v }, t)));
    if (!e.commits[choix.cible]) choix.cible = "A";
    m.value = choix.cible; m.disabled = fige;
    racine.querySelector("[data-cle=mode]").value = choix.mode; racine.querySelector("[data-cle=mode]").disabled = fige;
    const b = nom => racine.querySelector(`[data-action=${nom}]`);
    b("commit").disabled = fige || plein; b("commit").title = plein ? `le simulateur gère ${MAX_COMMITS} commits au plus` : "";
    b("branch").disabled = fige || !libres.length; b("switch").disabled = fige || !autres.length;
    b("merge").disabled = fige || !autres.length; b("rebase").disabled = fige || !autres.length; b("reset").disabled = fige;
    racine.querySelector(".toile").replaceChildren(dessinerGraphe());
    ajuster();
    dessinerZones(); dessinerExplication();
  }
  const reinit = () => { sim = depart(); choix = { branche: "contact", vers: "", fusion: "", rebase: "", mode: "mixed", cible: "A" }; derniere = []; signal = new Set(); };

  // Joue une commande : le graphe change d'abord, l'explication vient ensuite.
  async function jouer(op) {
    const r = appliquer(sim, op), moi = ++tour;
    signal = new Set();
    if (!r.erreur && !r.limite) {
      const avant = sim.branches, tete0 = sim.tete;
      sim = r.etat;
      for (const n of sim.ordre) if (!r.avant.commits[n]) signal.add(n);
      for (const [b, cmt] of Object.entries(sim.branches)) if (avant[b] !== cmt) signal.add(`branche:${b}`);
      if (sim.tete !== tete0 || signal.size) signal.add("HEAD");
      if (op.op === "switch") signal.add("HEAD");
    }
    derniere = expliquer(r);
    phase = 1;
    dessiner();
    await moteur.attendre(PHASE);
    if (moi !== tour) return null;
    phase = 2; dessiner();
    return derniere;
  }
  // Plusieurs commandes d'une même étape : leurs lignes de commande se suivent, puis l'explication de la dernière ;
  // une limitation, une erreur ou un danger d'une commande plus ancienne reste affiché.
  async function enchainer(ops) {
    const res = [];
    for (const op of ops) { const f = await jouer(op); if (f === null) return []; res.push(f); }
    const phrases = [`$ ${res.map(f => f[0].slice(2)).join(" ; ")}`];
    res.forEach((f, i) => f.slice(1).forEach(x => { if (i === res.length - 1 || /^(Danger|Impossible|Limitation)/.test(x)) phrases.push(x); }));
    derniere = phrases; dessiner();
    return phrases;
  }
  const mainLibre = async op => { await jouer(op); moteur.libre(derniere); };

  // ---------- Contrôles ----------
  const menu = (cle, etiquette, options, onchange) => el("select", { "data-cle": cle, "aria-label": etiquette, onchange: ev => onchange(ev.target.value) },
    ...options.map(([v, t]) => el("option", { value: v }, t)));
  const groupe = (...enfants) => el("span", { class: "groupe" }, ...enfants);
  function construire() {
    racine.replaceChildren(
      el("section", { class: "zone-commandes" },
        el("div", { class: "commandes" },
          el("div", { class: "rangee" },
            bouton("git commit", () => mainLibre({ op: "commit" }), { "data-action": "commit", title: "un nouveau fichier, git add, git commit" }),
            groupe(bouton("git branch", () => mainLibre({ op: "branch", nom: choix.branche }), { "data-action": "branch" }),
              menu("branche", "Nom de la nouvelle branche", [], v => { choix.branche = v; })),
            groupe(bouton("git switch", () => mainLibre({ op: "switch", nom: choix.vers }), { "data-action": "switch" }),
              menu("vers", "Branche où placer HEAD", [], v => { choix.vers = v; })),
            groupe(bouton("git merge", () => mainLibre({ op: "merge", nom: choix.fusion }), { "data-action": "merge" }),
              menu("fusion", "Branche à fusionner dans la branche courante", [], v => { choix.fusion = v; })),
            groupe(bouton("git rebase", () => mainLibre({ op: "rebase", nom: choix.rebase }), { "data-action": "rebase" }),
              menu("rebase", "Branche sur laquelle rejouer la branche courante", [], v => { choix.rebase = v; }))),
          el("div", { class: "rangee" },
            groupe(bouton("git reset", () => mainLibre({ op: "reset", mode: choix.mode, cible: choix.cible }), { "data-action": "reset" }),
              menu("mode", "Mode du reset", [["soft", "--soft"], ["mixed", "--mixed"], ["hard", "--hard"]], v => { choix.mode = v; }),
              menu("cible", "Commit visé par le reset", [], v => { choix.cible = v; })),
            bouton("Remettre à zéro", () => { moteur.fermer(); tour++; reinit(); phase = 2; dessiner(); }, { class: "zero-bouton" })))),
      el("section", { class: "zone-graphe cadre" },
        el("div", { class: "titre-zone" }, el("h2", {}, "Graphe des commits"),
          el("p", { class: "mention" }, "Flèche : du commit à son parent. Bleu : créé sur main ; orange : sur une autre branche ; tirets : sur aucune (git reflog le retrouve).")),
        el("div", { class: "toile" })),
      el("div", { class: "bas" },
        el("section", { class: "zone-explication cadre" }, el("h2", {}, "Ce que dit le résultat"),
          el("div", { class: "explication-texte", role: "status", "aria-live": "polite" })),
        el("section", { class: "zone-zones cadre" }, el("h2", {}, "Les trois zones"), el("div", { class: "zones" }))));
    // le graphe suit la taille de sa zone
    new ResizeObserver(() => ajuster()).observe(racine.querySelector(".toile"));
  }

  // ---------- Recettes ----------
  const etape = ops => async () => enchainer(ops);
  const premiere = ops => async () => { reinit(); return enchainer(ops); };
  const RECETTES = Object.fromEntries(Object.entries(SCENARIOS).map(([nom, etapes]) =>
    [nom, etapes.map(([titre, ops], i) => [titre, i === 0 ? premiere(ops) : etape(ops)])]));
  const capturer = () => structuredClone({ sim, choix, derniere, signal: [...signal] });
  function retablir(sauvegarde) {
    tour++;   // une commande en cours d'exécution est abandonnée
    const x = structuredClone(sauvegarde);
    sim = x.sim; choix = x.choix; derniere = x.derniere; signal = new Set(); phase = 2;
    dessiner();
  }
  const moteur = recettes({ recettes: RECETTES, depart: ["Départ : un dépôt avec un seul commit, A, sur main ; HEAD désigne main."],
    titreLibre: "Votre commande", pause: () => PAUSE,
    remettre: () => { reinit(); phase = 2; dessiner(); }, capturer, retablir, afficher: () => dessiner() });

  construire();
  dessiner();
})();
