// cache-de-build.js — simulateur du cache de build, selon le modèle du cours :
// clé d’une étape = empreinte de (clé du parent + instruction + contenu du fichier copié) ;
// cache de build : clé → couche. Une étape dont la clé est connue est réutilisée (CACHED).
// Le build se déroule dans le temps : une étape en cache est immédiate, une étape exécutée fait attendre.
// Des recettes rejouent, pas à pas, les manipulations des expériences de la page.
(() => {
  const racine = document.getElementById("artefact");
  const ACCELERATION = 10;   // 38 s simulées durent 3,8 s réelles
  const ATTENTE_MIN = 250;   // en ms : même une copie de 0,1 s se voit passer
  const PAUSE = 1100;        // en ms : le temps de lire ce qu’une recette vient de faire

  const depart = () => ({
    instructions: [
      "FROM debian:13",
      "COPY index.php /var/www/html/",
      "RUN apt-get update && apt-get install -y apache2 libapache2-mod-php",
      "COPY site.conf /etc/apache2/sites-available/000-default.conf",
      'CMD ["apache2ctl", "-D", "FOREGROUND"]',
    ],
    fichiers: { "index.php": "<?php echo 'Bonjour';", "site.conf": "DocumentRoot /var/www/html" },
  });
  let { instructions, fichiers } = depart();
  // Le cache : clé → { instruction, source, contenu, cree, appel, rejouee }, où cree et appel sont des numéros de build.
  const cache = new Map();
  const historique = [];     // un élément par build : { duree, complet, sansCache }
  let dernier = null;        // les étapes du build affiché
  let precedent = null;      // celles du build d’avant, pour dire pourquoi une étape est rejouée
  let affiche = false;       // le résultat affiché correspond-il encore au Dockerfile ?
  let erreur = null;
  let enCours = false, presser = false, sansAttente = false;
  let recette = null;        // la recette en cours : { nom, pas, arret }

  // Empreinte courte (FNV-1a, 32 bits) : elle tient lieu du hash que calcule BuildKit.
  const empreinte = texte => {
    let h = 0x811c9dc5;
    for (const c of new TextEncoder().encode(texte)) { h ^= c; h = Math.imul(h, 0x01000193) >>> 0; }
    return h.toString(16).padStart(8, "0");
  };
  const mot = instruction => instruction.trim().split(/\s+/)[0].toUpperCase();
  const copie = instruction => ["COPY", "ADD"].includes(mot(instruction));
  // Les instructions que BuildKit numérote [k/n] ; les autres (CMD, ENV…) ne créent pas de couche.
  const etape = instruction => ["FROM", "RUN", "COPY", "ADD", "WORKDIR"].includes(mot(instruction));
  // Durées fictives, en secondes : installer des paquets est long, copier un fichier est immédiat.
  const duree = instruction => {
    if (mot(instruction) === "RUN") return /\binstall\b/.test(instruction) ? 38 : /\bupdate\b/.test(instruction) ? 6 : 2;
    return copie(instruction) ? 0.1 : 0;
  };
  const secondes = s => s.toFixed(1).replace(".", ",") + " s";

  // Ce que le build va faire de chaque instruction, d’après le cache tel qu’il est.
  function planifier(sansCache) {
    if (mot(instructions[0]) !== "FROM") { erreur = "Un Dockerfile commence par une instruction FROM."; return null; }
    const cacheVide = cache.size === 0;
    const etapes = [];
    let parent = "";
    for (const [i, brute] of instructions.entries()) {
      const instruction = brute.trim();
      let source = null, contenu = "";
      if (copie(instruction)) {
        source = instruction.split(/\s+/)[1];
        if (!(source in fichiers)) { erreur = `${mot(instruction)} : « ${source ?? ""} » n’est pas dans le contexte de build.`; return null; }
        contenu = fichiers[source];
      }
      const cle = empreinte([parent, instruction, contenu].join("\n"));
      const couche = i > 0 && etape(instruction);   // seules ces étapes ont une couche, donc une entrée de cache
      const executee = couche && (sansCache || !cache.has(cle));
      const avant = precedent?.[i];
      let raison = "";
      if (executee) {
        raison = sansCache ? "option --no-cache : le cache n’est pas consulté"
          : cacheVide ? "le cache est vide"
          : !avant || avant.parent !== parent ? "l’étape précédente a changé : celle-ci n’a plus le même parent"
          : avant.instruction !== instruction ? "l’instruction a changé"
          : avant.contenu !== contenu ? `le contenu de ${source} a changé`
          : "cette clé n’est pas dans le cache";
      }
      etapes.push({ instruction, source, contenu, cle, parent, couche, executee, raison, cout: couche ? duree(instruction) : 0, etat: "attente" });
      parent = cle;
    }
    return etapes;
  }

  async function construire(sansCache) {
    if (enCours) { presser = true; return; }   // le bouton principal sert alors à passer l’attente
    erreur = null;
    precedent = dernier;
    const plan = planifier(sansCache);
    if (!plan) { affiche = false; return dessiner(); }
    const numero = historique.length + 1;
    dernier = plan; affiche = true; enCours = true; presser = false;
    dessiner();
    const aFaire = plan.reduce((s, e) => s + (e.executee ? e.cout : 0), 0);
    let fait = 0;
    avancer(0, aFaire);
    for (const [i, e] of plan.entries()) {
      if (e.executee) {
        e.etat = "encours"; majLigne(i);
        await attendre(e, i, t => avancer(fait + t, aFaire));
        fait += e.cout;
      }
      if (e.couche) {
        const entree = cache.get(e.cle);
        cache.set(e.cle, { instruction: e.instruction, source: e.source, contenu: e.contenu,
          cree: entree ? entree.cree : numero, appel: numero, rejouee: e.executee });
        dessinerCache(numero);
      }
      e.etat = "fait"; majLigne(i);
    }
    historique.push({ duree: aFaire, complet: plan.reduce((s, e) => s + e.cout, 0), sansCache });
    enCours = false;
    dessiner();
  }
  // Fait attendre le temps de l’étape, accéléré ; `suivi(t)` reçoit le temps simulé écoulé.
  function attendre(e, i, suivi) {
    const reel = sansAttente ? 0 : Math.max(ATTENTE_MIN, e.cout * 1000 / ACCELERATION);
    const debut = performance.now();
    const li = racine.querySelectorAll(".dockerfile li")[i];
    const statut = li.querySelector(".statut");
    return new Promise(fini => {
      const tic = () => {
        const t = performance.now() - debut;
        if (presser || t >= reel) return fini();
        const simule = e.cout * t / reel;
        statut.textContent = simule.toFixed(1) + "s …";
        li.style.setProperty("--avance", (100 * t / reel).toFixed(1) + "%");
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

  // ---------- Recettes : les manipulations des expériences, jouées pas à pas ----------
  const pause = () => new Promise(fini => setTimeout(fini, sansAttente ? 80 : PAUSE));
  const build = () => construire(false);
  // Change le contenu d’un fichier du contexte, comme le ferait le lecteur.
  const ecrire = (nom, contenu) => async () => { fichiers[nom] = contenu; affiche = false; dessiner(); signaler(`.contexte input[data-fichier="${nom}"]`); };
  // Descend l’instruction qui commence par `debut` sous celle qui la suit.
  const descendre = debut => async () => {
    const i = instructions.findIndex(x => x.startsWith(debut));
    [instructions[i], instructions[i + 1]] = [instructions[i + 1], instructions[i]];
    affiche = false; dessiner(); signaler(`.dockerfile li:nth-child(${i + 2}) input`);
  };
  const signaler = selecteur => racine.querySelector(selecteur)?.classList.add("signale");
  const RECETTES = {
    "deux-builds": [
      ["Premier build : le cache est vide.", build],
      ["Second build, sans rien changer.", build],
    ],
    "code-modifie": [
      ["Premier build.", build],
      ["On modifie le contenu de index.php.", ecrire("index.php", "<?php echo 'Salut';")],
      ["On reconstruit.", build],
    ],
    "stables-dabord": [
      ["Premier build, dans l’ordre de départ.", build],
      ["On descend COPY index.php sous le RUN.", descendre("COPY index.php")],
      ["On reconstruit : l’installation est rejouée une dernière fois.", build],
      ["On modifie index.php.", ecrire("index.php", "<?php echo 'Salut';")],
      ["On reconstruit.", build],
    ],
    "contenu-deja-construit": [
      ["Premier build, avec « Bonjour ».", build],
      ["On écrit « Salut » dans index.php.", ecrire("index.php", "<?php echo 'Salut';")],
      ["Build avec « Salut ».", build],
      ["On remet « Bonjour ».", ecrire("index.php", "<?php echo 'Bonjour';")],
      ["On reconstruit.", build],
    ],
    "depots-a-jour": [
      ["Premier build : apt-get update télécharge les listes de paquets.", build],
      ["Plus tard, les dépôts Debian ont changé ; le Dockerfile, non. On reconstruit.", build],
      ["On reconstruit avec --no-cache.", () => construire(true)],
    ],
  };
  async function jouer(nom) {
    if (recette) { recette.arret = true; presser = true; return; }   // le bouton sert alors à arrêter
    remettreAZero();
    recette = { nom, pas: 0, arret: false };
    for (const [i, [, action]] of RECETTES[nom].entries()) {
      recette.pas = i; dessiner(); majRecettes();
      await pause();
      if (recette.arret) break;
      await action();
      if (recette.arret) break;
      await pause();
    }
    recette = null;
    dessiner(); majRecettes();
  }
  // Chaque expérience de la page qui nomme une recette reçoit ses étapes et un bouton pour la jouer.
  const cartes = [...document.querySelectorAll(".experience[data-recette]")].filter(c => RECETTES[c.dataset.recette]);
  function majRecettes() {
    for (const carte of cartes) {
      const nom = carte.dataset.recette, active = recette?.nom === nom;
      let bloc = carte.querySelector(".recette");
      if (!bloc) { bloc = el("div", { class: "recette" }); carte.querySelector("details").before(bloc); }
      bloc.replaceChildren(
        bouton(active ? "■ Arrêter" : "▶ Jouer la recette", () => jouer(nom), { class: "jouer", disabled: (recette && !active) && "" }),
        el("ol", {}, ...RECETTES[nom].map(([texte], i) =>
          el("li", { class: !active ? "" : i < recette.pas ? "faite" : i === recette.pas ? "courante" : "",
            "aria-current": active && i === recette.pas ? "step" : false }, texte))));
    }
  }

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
    cache.clear(); historique.length = 0; dernier = precedent = null; affiche = false; erreur = null;
  }
  // Toute modification rend le résultat caduc : il s’efface jusqu’au prochain build.
  const modifier = action => { action(); affiche = false; erreur = null; dessiner(); };
  // Pendant la saisie, le résultat s’efface sur place : redessiner retirerait le champ des mains du lecteur.
  function perimer() {
    if (!affiche && !erreur) return;
    affiche = false; erreur = null;
    for (const e of racine.querySelectorAll(".dockerfile .statut, .dockerfile .detail")) e.textContent = "";
    racine.querySelectorAll(".dockerfile li").forEach((li, i) => { li.className = classeLigne(i, ""); });
    const bilan = racine.querySelector(".bilan");
    bilan.className = "bilan"; bilan.textContent = PERIME;
    racine.querySelector(".progression .texte").textContent = "";
    racine.querySelector(".progression .barre").style.width = "0";
  }
  const echanger = (i, j) => modifier(() => { [instructions[i], instructions[j]] = [instructions[j], instructions[i]]; });

  // Une instruction sans couche (FROM, CMD…) n’a ni clé de cache ni détail à afficher : sa ligne est plus basse.
  const classeLigne = (i, classe) => (i > 0 && etape(instructions[i]) ? classe : (classe + " sans-couche").trim());
  // Ce qu’une ligne du Dockerfile dit du build : sa classe, son statut, son détail.
  function lecture(e, i) {
    if (!e || e.etat === "attente") return ["", "", ""];
    if (e.etat === "encours") return ["encours", "0.0s …", "exécution : " + e.raison];
    if (i === 0) return ["", "image de base", ""];
    if (!e.couche) return ["", "pas de couche", ""];
    return e.executee ? ["executee", "DONE " + e.cout.toFixed(1) + "s", "clé " + e.cle + " · rejouée : " + e.raison]
      : ["reutilisee", "CACHED", "clé " + e.cle + " · déjà dans le cache"];
  }
  function majLigne(i) {
    const li = racine.querySelectorAll(".dockerfile li")[i];
    const [classe, statut, detail] = lecture(dernier[i], i);
    li.className = classeLigne(i, classe);
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
        title: c.instruction + (c.source ? `\n${c.source} : ${c.contenu}` : "") },
      el("code", { class: "cle" }, cle),
      el("span", { class: "quoi" }, c.source ? `${mot(c.instruction)} ${c.source} « ${c.contenu} »` : c.instruction),
      el("span", { class: "etat" }, nom)));
    racine.querySelector(".zone-cache").replaceChildren(
      el("h2", {}, `Cache de build : ${cache.size} couche${cache.size > 1 ? "s" : ""}`),
      el("p", { class: "legende" }, "clé → couche, et ce que le dernier build en a fait"),
      cache.size ? el("ul", { class: "cache" }, ...liste) : el("p", { class: "vide" }, "Vide : aucune couche construite."));
  }

  function dessiner() {
    const fige = enCours || !!recette;   // pendant un build ou une recette, le lecteur regarde
    const total = instructions.filter(etape).length;
    let k = 0;
    const dockerfile = el("ol", { class: "dockerfile" }, ...instructions.map((instruction, i) => {
      const [classe, statut, detail] = lecture(affiche ? dernier[i] : null, i);
      return el("li", { class: classeLigne(i, classe) },
        el("span", { class: "numero" }, etape(instruction) ? `[${++k}/${total}]` : ""),
        el("input", {
          type: "text", value: instruction, spellcheck: "false", "aria-label": `Instruction ${i + 1}`, disabled: fige && "",
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
      bouton(enCours ? "Passer l’attente" : "docker image build", () => construire(false), { class: "principal", disabled: (recette && !enCours) && "" }),
      bouton("avec --no-cache", () => construire(true), { "aria-label": "docker image build --no-cache", disabled: fige && "" }),
      bouton("Vider le cache", () => modifier(() => cache.clear()), { title: "docker builder prune", disabled: fige && "" }),
      el("label", { class: "sans-attente" },
        el("input", { type: "checkbox", checked: sansAttente && "", onchange: ev => { sansAttente = ev.target.checked; } }), "sans attente"),
    );
    const zero = bouton("Remettre à zéro", () => { remettreAZero(); dessiner(); }, { class: "zero", disabled: fige && "" });

    const h = historique.at(-1);
    const gain = h ? h.complet - h.duree : 0;
    const progression = el("div", { class: "progression", role: "progressbar", "aria-label": "Avancement du build",
        "aria-valuemin": "0", "aria-valuemax": "100", "aria-valuenow": affiche && !enCours ? "100" : "0" },
      el("span", { class: "piste" }, el("span", { class: "barre" })), el("span", { class: "texte" }));
    if (affiche && !enCours && h) {
      progression.querySelector(".barre").style.width = "100%";
      progression.querySelector(".texte").textContent = h.duree > 0 ? `${secondes(h.duree)} sur ${secondes(h.duree)}` : "tout est en cache";
    }
    const bilan = el("p", { class: erreur ? "bilan erreur" : "bilan", role: "status", "aria-live": "polite" },
      erreur ? "ERROR : " + erreur
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
