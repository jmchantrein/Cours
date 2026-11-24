// cache-de-build.js — simulateur du cache de build, selon le modèle du cours :
// clé d’une étape = empreinte de (clé du parent + instruction + contenu du fichier copié) ;
// cache de build : clé → couche. Une étape dont la clé est connue est réutilisée (CACHED).
//
// Ce que le simulateur affirme a été confronté à BuildKit (Docker Engine 29.10, voir verifier-buildkit.js) :
// - seules FROM, RUN et COPY forment la chaîne des clés ; CMD, ENTRYPOINT, LABEL et EXPOSE n’y entrent pas ;
// - une ligne vide ou un commentaire ne change rien ; la casse du mot-clé et les espaces autour non plus ;
// - la commande d’un RUN compte au caractère près ; la date d’un fichier copié ne compte pas.
// Ce qu’il ne sait pas simuler (ENV, USER, WORKDIR, ADD, ARG… ; COPY hors de sa forme simple), il le dit au lieu
// de répondre. Les explications sont calculées à partir du résultat du build, jamais écrites d’avance.
//
// Le build se déroule dans le temps : une étape en cache est immédiate, une étape exécutée fait attendre.
// Des recettes rejouent, pas à pas, les manipulations des expériences de la page.
(() => {
  const racine = document.getElementById("artefact");
  const ACCELERATION = 10;   // 38 s simulées durent 3,8 s réelles
  const ATTENTE_MIN = 250;   // en ms : même une copie de 0,1 s se voit passer
  const PAUSE = 1100;        // en ms : entre deux étapes d’une recette qui s’enchaîne sans pause

  const IMAGE = "debian:13";
  const INSTALLATION = "apt-get update && apt-get install -y apache2 libapache2-mod-php";
  const depart = () => ({
    instructions: [
      "FROM " + IMAGE,
      "COPY index.php /var/www/html/",
      "RUN " + INSTALLATION,
      "COPY site.conf /etc/apache2/sites-available/000-default.conf",
      'CMD ["apache2ctl", "-D", "FOREGROUND"]',
    ],
    fichiers: { "index.php": "<?php echo 'Bonjour';", "site.conf": "DocumentRoot /var/www/html" },
  });
  let { instructions, fichiers } = depart();
  // Le cache : clé → { texte, source, contenu, parent, cree, appel, rejouee } ; cree et appel sont des numéros de build.
  const cache = new Map();
  const historique = [];     // un élément par build : { duree, complet, sansCache }
  let dernier = null;        // les lignes du build affiché
  let affiche = false;       // le résultat affiché correspond-il encore au Dockerfile ?
  let echec = null;          // { genre: "erreur" (Docker échouerait) | "limite" (le simulateur ne sait pas), message }
  let enCours = false, presser = false, sansAttente = false;
  let tour = 0;              // numéro du build lancé : un build annulé (retour en arrière) s’y reconnaît
  // La recette ouverte : { nom, pas (étapes faites), etats et explications (après chaque étape), occupe (une étape
  // s’exécute), gel (elle est en pause), lecture (les étapes s’enchaînent), libre (le lecteur a repris la main) }.
  let recette = null;
  let continu = false;       // les recettes s’enchaînent-elles sans pause entre deux étapes ?

  // Empreinte courte (FNV-1a, 32 bits) : elle tient lieu du hash que calcule BuildKit.
  const empreinte = texte => {
    let h = 0x811c9dc5;
    for (const c of new TextEncoder().encode(texte)) { h ^= c; h = Math.imul(h, 0x01000193) >>> 0; }
    return h.toString(16).padStart(8, "0");
  };
  const secondes = s => s.toFixed(1).replace(".", ",") + " s";
  const court = (texte, n = 34) => (texte.length > n ? texte.slice(0, n - 1) + "…" : texte);

  // ---------- Le modèle ----------
  const SANS_EFFET = ["CMD", "ENTRYPOINT", "LABEL", "EXPOSE"];   // configuration de l’image : hors de la chaîne des clés
  const NON_SIMULEES = ["ADD", "ENV", "ARG", "USER", "WORKDIR", "VOLUME", "SHELL", "HEALTHCHECK", "STOPSIGNAL", "ONBUILD", "MAINTAINER"];
  // Ce qu’est une ligne du Dockerfile : { genre, mot, texte (forme normalisée), source }, ou un échec.
  function analyser(ligne, i) {
    const brute = ligne.trim();
    if (!brute || brute.startsWith("#")) return { genre: "vide" };
    const mot = brute.split(/\s+/)[0].toUpperCase(), reste = brute.slice(mot.length).trim();
    if (mot === "FROM") {
      return i === 0 ? { genre: "from", mot, texte: "FROM " + reste }
        : { echec: { genre: "limite", message: "un seul FROM est simulé (pas de build en plusieurs étapes)" } };
    }
    if (mot === "RUN") {
      return reste ? { genre: "run", mot, texte: "RUN " + reste, commande: reste }
        : { echec: { genre: "erreur", message: "RUN demande une commande" } };
    }
    if (mot === "COPY") {
      const [source, destination, ...autres] = reste.split(/\s+/);
      const simple = source && destination && !autres.length && /^[\w][\w.-]*$/.test(source)
        && /^\/[\w.\/-]*$/.test(destination) && !/\/\.{1,2}(\/|$)|\/\//.test(destination);
      if (!simple) return { echec: { genre: "limite", message: "COPY n’est simulé que pour un fichier du contexte vers un chemin absolu, comme « COPY index.php /var/www/html/ »" } };
      if (!(source in fichiers)) return { echec: { genre: "erreur", message: `"/${source}": not found — ce fichier n’est pas dans le contexte de build` } };
      return { genre: "copy", mot, texte: `COPY ${source} ${destination}`, source };
    }
    if (SANS_EFFET.includes(mot)) return { genre: "config", mot };
    if (NON_SIMULEES.includes(mot)) return { echec: { genre: "limite", message: `l’instruction ${mot} n’est pas simulée` } };
    return { echec: { genre: "erreur", message: `unknown instruction: ${mot} — Docker ne connaît pas cette instruction` } };
  }
  // Durées fictives, en secondes : installer des paquets est long, copier un fichier est immédiat.
  const duree = a => a.genre === "copy" ? 0.1 : a.genre !== "run" ? 0
    : /\binstall\b/.test(a.commande) ? 38 : /\bupdate\b/.test(a.commande) ? 6 : 2;
  // Pourquoi une étape n’est pas dans le cache : on la compare aux couches que le cache possède.
  function raison(a, parent, contenu, sansCache) {
    if (sansCache) return "l’option --no-cache fait ignorer le cache";
    if (cache.size === 0) return "le cache est vide";
    const memes = [...cache.values()].filter(c => c.texte === a.texte);
    if (!memes.length) return "cette instruction n’a encore jamais été construite";
    if (a.genre === "copy" && memes.some(c => c.parent === parent)) return `le contenu de ${a.source} a changé`;
    if (memes.some(c => c.contenu === contenu)) return "son parent a changé : l’étape précédente n’a plus la même clé";
    return `le cache n’a aucune couche de cette instruction avec ce parent et ce contenu de ${a.source}`;
  }
  // Ce que le build va faire de chaque ligne, d’après le cache tel qu’il est. Rend null en cas d’échec.
  function planifier(sansCache) {
    const analyses = instructions.map(analyser);
    const fautif = analyses.find(a => a.echec);
    if (!fautif && analyses.find(a => a.genre !== "vide")?.genre !== "from") {
      echec = { genre: "erreur", message: "no build stage in current context — le Dockerfile doit commencer par FROM" };
      return null;
    }
    if (fautif) { echec = fautif.echec; return null; }
    let parent = "";
    return analyses.map((a, i) => {
      const ligne = { instruction: instructions[i].trim(), genre: a.genre, couche: false, executee: false, cout: 0, etat: "attente" };
      if (a.genre === "from") parent = empreinte(a.texte);
      if (a.genre === "run" || a.genre === "copy") {
        const contenu = a.genre === "copy" ? fichiers[a.source] : "";
        const cle = empreinte([parent, a.texte, contenu].join("\n"));
        const executee = sansCache || !cache.has(cle);
        Object.assign(ligne, { couche: true, cle, parent, texte: a.texte, source: a.source ?? null, contenu, executee, cout: duree(a),
          raison: executee ? raison(a, parent, contenu, sansCache) : "",
          // Le simulateur ne peut pas savoir si une commande qu’il ne connaît pas réussirait.
          supposee: a.genre === "run" && a.commande !== INSTALLATION });
        parent = cle;
      }
      return ligne;
    });
  }

  async function construire(sansCache) {
    if (enCours) { presser = true; return; }   // le bouton principal sert alors à passer l’attente
    echec = null;
    const plan = planifier(sansCache);
    if (!plan) { affiche = false; dessiner(); return apresBuild(); }
    const numero = historique.length + 1, moi = ++tour;
    dernier = plan; affiche = true; enCours = true; presser = false;
    dessiner();
    const aFaire = plan.reduce((s, e) => s + (e.executee ? e.cout : 0), 0);
    let fait = 0;
    avancer(0, aFaire);
    for (const [i, e] of plan.entries()) {
      if (e.executee) {
        e.etat = "encours"; majLigne(i);
        await attendre(e, i, t => avancer(fait + t, aFaire));
        if (moi !== tour) return;   // build annulé : l’état a été rétabli par ailleurs
        fait += e.cout;
      }
      if (e.couche) {
        const entree = cache.get(e.cle);
        cache.set(e.cle, { texte: e.texte, source: e.source, contenu: e.contenu, parent: e.parent,
          cree: entree ? entree.cree : numero, appel: numero, rejouee: e.executee });
        dessinerCache(numero);
      }
      e.etat = "fait"; majLigne(i);
    }
    historique.push({ duree: aFaire, complet: plan.reduce((s, e) => s + e.cout, 0), sansCache });
    enCours = false;
    dessiner();
    apresBuild();
  }
  // Fait attendre le temps de l’étape, accéléré ; `suivi(t)` reçoit le temps simulé écoulé.
  // Une recette en pause gèle l’attente : le temps ne s’écoule plus.
  function attendre(e, i, suivi) {
    const reel = sansAttente ? 0 : Math.max(ATTENTE_MIN, e.cout * 1000 / ACCELERATION);
    const li = racine.querySelectorAll(".dockerfile li")[i];
    const statut = li.querySelector(".statut");
    let ecoule = 0, avant = performance.now();
    return new Promise(fini => {
      const tic = () => {
        const maintenant = performance.now();
        if (!recette?.gel) ecoule += maintenant - avant;
        avant = maintenant;
        if (presser || ecoule >= reel) return fini();
        const simule = e.cout * ecoule / reel;
        statut.textContent = simule.toFixed(1) + "s …";
        li.style.setProperty("--avance", (100 * ecoule / reel).toFixed(1) + "%");
        suivi(simule);
        setTimeout(tic, 60);
      };
      tic();
    });
  }
  // La barre de progression du build : le temps simulé écoulé sur le temps à passer.
  function avancer(ecoule, total) {
    const barre = racine.querySelector(".progression");
    if (!barre) return;
    const part = total > 0 ? Math.min(1, ecoule / total) : 1;
    barre.setAttribute("aria-valuenow", Math.round(100 * part));
    barre.querySelector(".barre").style.width = (100 * part).toFixed(1) + "%";
    barre.querySelector(".texte").textContent = total > 0 ? `${secondes(ecoule)} sur ${secondes(total)}` : "tout est en cache";
  }

  // ---------- Explications : calculées à partir de ce qui vient de se passer ----------
  const LIMITE = "Limitation du simulateur : ce cas n’est pas expliqué.";
  // Le dernier build, en phrases. Chaque phrase est tirée du résultat ; un cas imprévu rend la mention de limitation.
  function expliquerBuild() {
    if (echec?.genre === "erreur") return [`Docker arrêterait le build : ${echec.message}.`,
      "Le simulateur n’a rien construit : il ne dit pas ce que Docker aurait mis en cache avant l’erreur."];
    if (echec) return [`Limitation du simulateur : ${echec.message}.`, "Il ne peut donc pas dire ce que Docker ferait de ce Dockerfile."];
    const h = historique.at(-1);
    if (!affiche || !dernier || !h) return [LIMITE];
    const couches = dernier.filter(e => e.couche), faites = couches.filter(e => e.executee);
    const n = couches.length, m = faites.length;
    const pluriel = (k, un, plusieurs) => `${k} ${k > 1 ? plusieurs : un}`;
    if (n === 0) return ["Ce Dockerfile ne crée aucune couche : il n’y avait rien à construire."];
    const phrases = [];
    if (h.sansCache) {
      phrases.push(`Avec --no-cache, le cache n’est pas consulté : ${pluriel(n, "étape exécutée", "étapes exécutées")}, en ${secondes(h.duree)}.`);
    } else if (m === 0) {
      phrases.push(`Rien n’a été exécuté : la clé de chaque étape (${n}) était déjà dans le cache.`,
        `Durée : ${secondes(0)} ; sans le cache, ce build aurait pris ${secondes(h.complet)}.`);
    } else {
      // Hors --no-cache, les étapes exécutées sont toujours les dernières : dès qu’une clé manque, celles d’après manquent aussi.
      if (couches.slice(n - m).some(e => !e.executee)) return [LIMITE];
      const premiere = faites[0];
      phrases.push(m === n
        ? `${n > 1 ? `Les ${n} étapes ont été exécutées` : "L’étape a été exécutée"}, en ${secondes(h.duree)}.`
        : `${pluriel(n - m, "étape réutilisée", "étapes réutilisées")}, ${pluriel(m, "exécutée", "exécutées")} : ${secondes(h.duree)} au lieu de ${secondes(h.complet)}.`);
      phrases.push(`« ${court(premiere.instruction)} » est exécutée parce que ${premiere.raison}.`
        + (m > 1 ? " Les suivantes le sont parce que leur clé contient celle de l’étape qui les précède." : ""));
    }
    const supposees = faites.filter(e => e.supposee);
    if (supposees.length) phrases.push(`Le simulateur suppose que « ${court(supposees[0].instruction)} »${supposees.length > 1 ? " et les autres commandes modifiées réussissent" : " réussit"} ; il ne peut pas le vérifier.`);
    return phrases;
  }
  const EFFACE = "Le résultat affiché valait pour l’état d’avant : il est effacé jusqu’au prochain build.";
  const A_VOUS = "Vous avez modifié le Dockerfile, un fichier ou le cache : lancez un build pour en lire l’explication.";

  // ---------- Recettes : les manipulations des expériences, jouées pas à pas ----------
  // Une action de recette agit sur la simulation, puis rend l’explication de ce qu’elle vient de faire.
  const build = sansCache => async () => { await construire(sansCache); return expliquerBuild(); };
  const ecrire = (nom, contenu) => async () => {
    const avant = fichiers[nom];
    fichiers[nom] = contenu; affiche = false; echec = null; dessiner();
    racine.querySelector(`.contexte input[data-fichier="${nom}"]`)?.classList.add("signale");
    return avant === contenu ? [`${nom} garde le même contenu.`]
      : [`${nom} contient maintenant « ${contenu} » ; avant : « ${avant} ».`, EFFACE];
  };
  const descendre = debut => async () => {
    const i = instructions.findIndex(x => x.startsWith(debut));
    if (i < 1 || i >= instructions.length - 1) return [LIMITE];
    const deplacee = instructions[i], depassee = instructions[i + 1];
    [instructions[i], instructions[i + 1]] = [depassee, deplacee];
    affiche = false; echec = null; dessiner();
    racine.querySelector(`.dockerfile li:nth-child(${i + 2}) input`)?.classList.add("signale");
    return [`« ${court(deplacee)} » passe de la ligne ${i + 1} à la ligne ${i + 2}, sous « ${court(depassee)} ».`, EFFACE];
  };
  // Les titres disent l’action que la recette va faire, pas son résultat : celui-ci est expliqué après coup.
  const RECETTES = {
    "deux-builds": [
      ["Premier build.", build(false)],
      ["Second build, sans rien changer.", build(false)],
    ],
    "code-modifie": [
      ["Premier build.", build(false)],
      ["Modifier le contenu de index.php.", ecrire("index.php", "<?php echo 'Salut';")],
      ["Reconstruire.", build(false)],
    ],
    "stables-dabord": [
      ["Premier build, dans l’ordre de départ.", build(false)],
      ["Descendre COPY index.php sous le RUN.", descendre("COPY index.php")],
      ["Reconstruire.", build(false)],
      ["Modifier le contenu de index.php.", ecrire("index.php", "<?php echo 'Salut';")],
      ["Reconstruire.", build(false)],
    ],
    "contenu-deja-construit": [
      ["Premier build, avec « Bonjour ».", build(false)],
      ["Écrire « Salut » dans index.php.", ecrire("index.php", "<?php echo 'Salut';")],
      ["Reconstruire.", build(false)],
      ["Remettre « Bonjour » dans index.php.", ecrire("index.php", "<?php echo 'Bonjour';")],
      ["Reconstruire.", build(false)],
    ],
    "depots-a-jour": [
      ["Premier build.", build(false)],
      ["Reconstruire, comme si les dépôts Debian avaient changé entre-temps.", build(false)],
      ["Reconstruire avec --no-cache.", build(true)],
    ],
  };
  const etapesDe = r => RECETTES[r.nom];
  const finie = r => r.pas >= etapesDe(r).length && !r.occupe;

  // L’état complet de la simulation : mémorisé après chaque étape d’une recette, pour pouvoir y revenir.
  const capturer = () => structuredClone({ instructions, fichiers, cache: [...cache], historique, dernier, affiche, echec });
  function retablir(etat) {
    const e = structuredClone(etat);
    ({ instructions, fichiers, dernier, affiche, echec } = e);
    cache.clear(); for (const [cle, couche] of e.cache) cache.set(cle, couche);
    historique.length = 0; historique.push(...e.historique);
    enCours = false;
    dessiner();
  }
  // Abandonne l’étape en cours d’exécution et revient à l’état qui la précédait.
  function annuler(r) {
    r.jeton++; tour++; presser = true; r.occupe = false; r.gel = false;
    retablir(r.etats[r.pas]);
  }
  function ouvrir(nom) {
    if (recette) fermer();
    remettreAZero();
    recette = { nom, pas: 0, etats: [capturer()], explications: [["Départ : le Dockerfile et les fichiers d’origine ; le cache est vide."]],
      occupe: false, gel: false, lecture: continu, libre: null, jeton: 0, enBoucle: false };
    dessiner(); majRecettes();
    continu ? defiler(recette) : executer(recette);
  }
  // Ferme la recette en laissant la simulation dans l’état où elle est.
  function fermer() {
    if (recette.occupe) annuler(recette);
    recette = null;
    dessiner(); majRecettes();
  }
  // Exécute l’étape suivante, puis mémorise l’état obtenu et son explication.
  async function executer(r) {
    const i = r.pas, jeton = ++r.jeton;
    r.occupe = true; r.libre = null; presser = false;
    dessiner(); majRecettes();
    const explication = await etapesDe(r)[i][1]();
    if (recette !== r || r.jeton !== jeton) return;   // étape annulée par un retour en arrière
    r.pas = i + 1; r.etats[r.pas] = capturer(); r.explications[r.pas] = explication; r.occupe = false; r.gel = false;
    dessiner(); majRecettes();
  }
  // Enchaînement sans pause : une étape, le temps de lire, la suivante… tant que la lecture n’est pas suspendue.
  async function defiler(r) {
    const dormir = ms => new Promise(fini => setTimeout(fini, ms));
    r.enBoucle = true;
    while (recette === r && r.lecture) {
      if (r.occupe) { await dormir(80); continue; }   // une étape lancée à la main se termine d’abord
      if (r.pas >= etapesDe(r).length) { r.lecture = false; break; }
      if (r.pas > 0) for (let reste = sansAttente ? 80 : PAUSE; reste > 0 && recette === r && r.lecture; reste -= 60) await dormir(60);
      if (recette !== r || !r.lecture || r.occupe) continue;
      await executer(r);
    }
    r.enBoucle = false;
    if (recette === r) { dessiner(); majRecettes(); }
  }
  // Le bouton principal : continuer, suspendre ou reprendre, rejouer — selon l’état de la recette.
  function avancerRecette() {
    const r = recette;
    if (r.occupe) { r.gel = !r.gel; r.lecture = continu && !r.gel; }               // pause ou reprise, au milieu de l’étape
    else if (r.pas >= etapesDe(r).length) { r.pas = 0; r.libre = null; retablir(r.etats[0]); r.lecture = continu; continu ? defiler(r) : executer(r); }
    else if (continu) { r.lecture = !r.lecture; if (r.lecture && !r.enBoucle) defiler(r); }
    else executer(r);
    majRecettes();
  }
  function reculerRecette() {
    const r = recette;
    r.lecture = false; r.libre = null;
    if (r.occupe) annuler(r);                                                        // revient avant l’étape en cours
    else if (r.pas > 0) { r.pas--; retablir(r.etats[r.pas]); }
    majRecettes();
  }
  function basculerContinu(coche) {
    continu = coche;
    const r = recette;
    if (!r) return;
    r.lecture = continu && !r.gel && !finie(r);
    if (r.lecture && !r.enBoucle) defiler(r);
    majRecettes();
  }
  // Après un build : si le lecteur a repris la main à la fin d’une recette, celle-ci lui explique son build.
  function apresBuild() {
    if (recette && !recette.occupe) { recette.libre = expliquerBuild(); majRecettes(); }
  }

  // Chaque expérience de la page qui nomme une recette reçoit sa carte : ses étapes, puis son lecteur.
  const cartes = [...document.querySelectorAll(".experience[data-recette]")].filter(c => RECETTES[c.dataset.recette]);
  function majRecettes() {
    for (const carte of cartes) {
      const nom = carte.dataset.recette, r = recette?.nom === nom ? recette : null, etapes = RECETTES[nom], n = etapes.length;
      let bloc = carte.querySelector(".recette");
      if (!bloc) { bloc = el("div", { class: "recette" }); carte.querySelector("details").before(bloc); }
      bloc.classList.toggle("ouverte", !!r);
      const sansPause = el("label", { class: "sans-pause" },
        el("input", { type: "checkbox", checked: continu && "", onchange: ev => basculerContinu(ev.target.checked) }), "sans pause entre les étapes");
      if (!r) {
        bloc.replaceChildren(
          el("div", { class: "recette-entete" }, el("span", { class: "recette-titre" }, "Recette"), el("span", {}, `${n} étapes`)),
          el("ol", { class: "recette-etapes" }, ...etapes.map(([titre]) => el("li", {}, titre))),
          el("div", { class: "lecteur" }, bouton("▶ Jouer la recette", () => ouvrir(nom), { class: "jouer" }), sansPause));
        continue;
      }
      const fin = finie(r);
      const rang = r.occupe ? r.pas + 1 : r.pas;
      const action = r.occupe ? `Étape ${rang} sur ${n} : ${etapes[r.pas][0]}`
        : r.pas === 0 ? "Avant la première étape" : `Étape ${rang} sur ${n} : ${etapes[r.pas - 1][0]}`;
      const explication = r.occupe ? [r.gel ? "En pause, au milieu de l’étape." : "En cours…"] : r.libre ?? r.explications[r.pas];
      const principal = r.occupe ? (r.gel ? "▶ Reprendre" : "❚❚ Pause") : fin ? "↻ Rejouer"
        : continu && r.lecture ? "❚❚ Pause" : r.pas === 0 ? "Commencer ▶" : "Continuer ▶";
      bloc.replaceChildren(
        el("div", { class: "recette-entete" }, el("span", { class: "recette-titre" }, "Recette"), el("span", { class: "recette-rang" }, action),
          bouton("✕", fermer, { class: "fermer", "aria-label": "Fermer la recette", title: "Fermer la recette" })),
        el("div", { class: "explication", role: "status", "aria-live": "polite" },
          el("p", { class: "explication-titre" }, r.occupe ? "Ce qui se passe" : r.libre ? "Votre build" : "Ce qui vient de se passer"),
          ...explication.map(phrase => el("p", {}, phrase))),
        el("p", { class: "recette-suite" }, fin ? "Recette terminée. À vous : modifiez, déplacez, reconstruisez."
          : r.occupe ? "" : `Ensuite : ${etapes[r.pas][0]}`),
        el("div", { class: "lecteur" },
          bouton("◀ Revenir", reculerRecette, { "aria-label": "Revenir à l’étape précédente", disabled: (r.pas === 0 && !r.occupe) && "" }),
          bouton(principal, avancerRecette, { class: "jouer" }), sansPause));
    }
  }
  // Changer d’expérience ferme la recette ouverte : sa carte ne serait plus visible.
  new MutationObserver(() => { if (recette && cartes.find(c => c.dataset.recette === recette.nom)?.hidden) fermer(); })
    .observe(document.querySelector(".experiences") ?? document.body, { subtree: true, attributes: true, attributeFilter: ["hidden"] });

  // ---------- Interface ----------
  const el = (balise, attributs = {}, ...enfants) => {
    const e = document.createElement(balise);
    for (const [k, v] of Object.entries(attributs)) {
      if (k.startsWith("on")) e.addEventListener(k.slice(2), v); else if (v !== false && v != null) e.setAttribute(k, v);
    }
    e.append(...enfants);
    return e;
  };
  const bouton = (texte, action, attributs = {}) => el("button", { type: "button", onclick: action, ...attributs }, texte);
  const PERIME = "Dockerfile, fichier ou cache modifié : reconstruisez.";
  function remettreAZero() {
    ({ instructions, fichiers } = depart());
    cache.clear(); historique.length = 0; dernier = null; affiche = false; echec = null;
  }
  // Le lecteur a modifié quelque chose à la main : une recette terminée le lui signale.
  const aLaMain = () => { if (recette) { recette.libre = [A_VOUS]; majRecettes(); } };
  // Toute modification rend le résultat caduc : il s’efface jusqu’au prochain build.
  const modifier = action => { action(); affiche = false; echec = null; dessiner(); aLaMain(); };
  // Pendant la saisie, le résultat s’efface sur place : redessiner retirerait le champ des mains du lecteur.
  function perimer() {
    aLaMain();
    if (!affiche && !echec) return;
    affiche = false; echec = null;
    for (const e of racine.querySelectorAll(".dockerfile .statut, .dockerfile .detail")) e.textContent = "";
    for (const li of racine.querySelectorAll(".dockerfile li")) li.classList.remove("executee", "reutilisee", "encours", "sans-detail");
    const bilan = racine.querySelector(".bilan");
    bilan.className = "bilan"; bilan.textContent = PERIME;
    racine.querySelector(".progression .texte").textContent = "";
    racine.querySelector(".progression .barre").style.width = "0";
  }
  const echanger = (i, j) => modifier(() => { [instructions[i], instructions[j]] = [instructions[j], instructions[i]]; });

  // Ce qu’une ligne du Dockerfile dit du build : sa classe, son statut, son détail.
  function lecture(e) {
    if (!e || e.etat === "attente") return ["", "", ""];
    if (e.etat === "encours") return ["encours", "0.0s …", "exécution : " + e.raison];
    if (e.genre === "from") return ["", "image de base", ""];
    if (e.genre === "config") return ["", "pas de couche", ""];
    if (!e.couche) return ["", "", ""];
    return e.executee ? ["executee", "DONE " + e.cout.toFixed(1) + "s", `clé ${e.cle} · exécutée : ${e.raison}${e.supposee ? " · réussite supposée" : ""}`]
      : ["reutilisee", "CACHED", `clé ${e.cle} · déjà dans le cache`];
  }
  function majLigne(i) {
    const li = racine.querySelectorAll(".dockerfile li")[i];
    const [classe, statut, detail] = lecture(dernier[i]);
    li.className = classe + (dernier[i].couche ? "" : " sans-detail");
    li.querySelector(".statut").textContent = statut;
    li.querySelector(".detail").textContent = detail;
  }

  // Le cache, clé par clé : ce que le dernier build en a fait.
  function dessinerCache(numero = historique.length) {
    const etat = c => c.appel !== numero ? ["reserve", "en réserve"] : c.cree === numero ? ["creee", "créée"]
      : c.rejouee ? ["creee", "reconstruite"] : ["reutilisee", "réutilisée"];
    const ordre = { reutilisee: 0, creee: 1, reserve: 2 };
    const entrees = [...cache.entries()].map(([cle, c]) => ({ cle, c, etat: etat(c) }))
      .sort((a, b) => ordre[a.etat[0]] - ordre[b.etat[0]] || b.c.appel - a.c.appel);
    const liste = entrees.map(({ cle, c, etat: [classe, nom] }) => el("li", { class: classe,
        title: `${c.texte}${c.source ? `\n${c.source} : ${c.contenu}` : ""}\nparent : ${c.parent}` },
      el("code", { class: "cle" }, cle),
      el("span", { class: "quoi" }, c.source ? `COPY ${c.source} « ${c.contenu} »` : c.texte),
      el("span", { class: "etat" }, nom)));
    racine.querySelector(".zone-cache").replaceChildren(
      el("h2", {}, `Cache de build : ${cache.size} couche${cache.size > 1 ? "s" : ""}`),
      el("p", { class: "legende" }, "clé → couche, et ce que le dernier build en a fait"),
      cache.size ? el("ul", { class: "cache" }, ...liste) : el("p", { class: "vide" }, "Vide : aucune couche construite."));
  }

  function dessiner() {
    // Pendant un build ou une recette en cours, le lecteur regarde ; une recette terminée lui rend la main.
    const fige = enCours || (!!recette && !finie(recette));
    const numerotees = instructions.map((x, i) => ["from", "run", "copy"].includes(analyser(x, i).genre));
    const total = numerotees.filter(Boolean).length;
    let k = 0;
    const dockerfile = el("ol", { class: "dockerfile" }, ...instructions.map((instruction, i) => {
      const [classe, statut, detail] = lecture(affiche ? dernier[i] : null);
      // Une ligne sans couche (FROM, CMD, commentaire…) n’a ni clé ni détail : elle est plus basse.
      const genre = analyser(instruction, i).genre;
      return el("li", { class: classe + (genre === "run" || genre === "copy" ? "" : " sans-detail"),
          title: genre === "config" ? "Configuration de l’image : cette instruction n’entre dans aucune clé" : false },
        el("span", { class: "numero" }, numerotees[i] ? `[${++k}/${total}]` : ""),
        // L’image de base est fixe : le simulateur ne sait pas reconnaître deux noms d’une même image.
        el("input", {
          type: "text", value: instruction, spellcheck: "false", "aria-label": `Instruction ${i + 1}`, disabled: (fige || i === 0) && "",
          title: i === 0 ? "L’image de base n’est pas modifiable dans ce simulateur" : false,
          oninput: ev => { instructions[i] = ev.target.value; perimer(); },
        }),
        bouton("↑", () => echanger(i, i - 1), { "aria-label": `Monter l’instruction ${i + 1}`, disabled: (fige || i < 2) && "" }),
        bouton("↓", () => echanger(i, i + 1), { "aria-label": `Descendre l’instruction ${i + 1}`, disabled: (fige || i === 0 || i === instructions.length - 1) && "" }),
        el("span", { class: "statut" }, statut),
        el("span", { class: "detail" }, detail),
      );
    }));
    const contexte = el("div", { class: "contexte" }, ...Object.keys(fichiers).map(nom => el("label", {},
      el("code", {}, nom),
      el("input", { type: "text", value: fichiers[nom], spellcheck: "false", disabled: fige && "", "data-fichier": nom,
        oninput: ev => { fichiers[nom] = ev.target.value; perimer(); } }),
    )));
    const commandes = el("div", { class: "commandes" },
      bouton(enCours ? "Passer l’attente" : "docker image build", () => construire(false), { class: "principal", disabled: (fige && !enCours) && "" }),
      bouton("avec --no-cache", () => construire(true), { "aria-label": "docker image build --no-cache", disabled: fige && "" }),
      bouton("Vider le cache", () => modifier(() => cache.clear()), { title: "docker builder prune", disabled: fige && "" }),
      el("label", { class: "sans-attente" },
        el("input", { type: "checkbox", checked: sansAttente && "", onchange: ev => { sansAttente = ev.target.checked; } }), "sans attente"),
    );
    const zero = bouton("Remettre à zéro", () => { if (recette) fermer(); remettreAZero(); dessiner(); }, { class: "zero", disabled: enCours && "" });

    const h = historique.at(-1);
    const gain = h ? h.complet - h.duree : 0;
    const progression = el("div", { class: "progression", role: "progressbar", "aria-label": "Avancement du build",
        "aria-valuemin": "0", "aria-valuemax": "100", "aria-valuenow": affiche && !enCours ? "100" : "0" },
      el("span", { class: "piste" }, el("span", { class: "barre" })), el("span", { class: "texte" }));
    if (affiche && !enCours && h) {
      progression.querySelector(".barre").style.width = "100%";
      progression.querySelector(".texte").textContent = h.duree > 0 ? `${secondes(h.duree)} sur ${secondes(h.duree)}` : "tout est en cache";
    }
    const bilan = el("p", { class: echec ? "bilan " + echec.genre : "bilan", role: "status", "aria-live": "polite" },
      echec ? (echec.genre === "erreur" ? "ERROR : " : "Limitation du simulateur : ") + echec.message + "."
        : enCours ? "Build en cours…"
        : !h ? "Lancez un premier build."
        : !affiche ? PERIME
        : `Build n° ${historique.length} : ${secondes(h.duree)}` + (h.sansCache ? ", cache ignoré (--no-cache)."
          : gain > 0.05 ? ` au lieu de ${secondes(h.complet)} : ${secondes(gain)} gagnées grâce au cache.`
          : ", rien n’était en cache."));
    // Les builds en barres, du plus récent au plus ancien : la longueur dit la durée, la classe ce que le cache a épargné.
    const reference = Math.max(...historique.map(b => b.complet), 1);
    const builds = el("ol", { class: "historique" }, ...historique.map((b, i) => {
      const part = b.complet ? b.duree / b.complet : 0;
      const barre = el("span", { class: "barre" });
      barre.style.width = Math.max(1.5, 100 * b.duree / reference) + "%";
      return el("li", { class: part > 0.95 ? "complet" : part < 0.05 ? "gagne" : "partiel" },
        el("span", { class: "rang" }, "n° " + (i + 1)),
        el("span", { class: "piste" }, barre),
        el("span", { class: "temps" }, secondes(b.duree)));
    }).reverse());

    racine.replaceChildren(
      el("section", { class: "zone-dockerfile" }, el("h2", {}, "Dockerfile, et ce que le dernier build en a fait"),
        el("p", { class: "mention" }, "Modifiez les instructions ; les flèches les déplacent."), zero, dockerfile),
      el("section", { class: "zone-contexte cadre" }, el("h2", {}, "Contexte de build : les fichiers"), contexte,
        el("p", { class: "mention" }, `Simulation : durées fictives, jouées ${ACCELERATION} fois plus vite ; clés simplifiées.`)),
      el("section", { class: "zone-build cadre" }, el("h2", {}, "Construire"), commandes, progression, bilan, builds),
      el("section", { class: "zone-cache cadre" }),
    );
    dessinerCache();
  }
  dessiner();
  majRecettes();
})();
