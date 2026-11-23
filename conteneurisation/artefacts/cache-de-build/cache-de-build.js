// cache-de-build.js — simulateur du cache de build, selon le modèle du cours :
// clé d’une étape = empreinte de (clé du parent + instruction + contenu du fichier copié) ;
// cache de build : clé → couche. Une étape dont la clé est connue est réutilisée (CACHED).
// Le build se déroule dans le temps : une étape en cache est immédiate, une étape exécutée fait attendre.
(() => {
  const racine = document.getElementById("artefact");
  const ACCELERATION = 10;   // 38 s simulées durent 3,8 s réelles
  const ATTENTE_MIN = 250;   // en ms : même une copie de 0,1 s se voit passer

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
    for (const [i, e] of plan.entries()) {
      if (e.executee) { e.etat = "encours"; majLigne(i); await attendre(e, i); }
      if (e.couche) {
        const entree = cache.get(e.cle);
        cache.set(e.cle, { instruction: e.instruction, source: e.source, contenu: e.contenu,
          cree: entree ? entree.cree : numero, appel: numero, rejouee: e.executee });
        dessinerCache(numero);
      }
      e.etat = "fait"; majLigne(i);
    }
    historique.push({
      duree: plan.reduce((s, e) => s + (e.executee ? e.cout : 0), 0),
      complet: plan.reduce((s, e) => s + e.cout, 0),
      sansCache,
    });
    enCours = false;
    dessiner();
  }
  // Fait attendre le temps de l’étape, accéléré, en affichant le temps simulé qui s’écoule.
  function attendre(e, i) {
    const reel = sansAttente ? 0 : Math.max(ATTENTE_MIN, e.cout * 1000 / ACCELERATION);
    const debut = performance.now();
    const statut = racine.querySelectorAll(".dockerfile .statut")[i];
    return new Promise(fini => {
      const tic = () => {
        const t = performance.now() - debut;
        if (presser || t >= reel) return fini();
        statut.textContent = (e.cout * t / reel).toFixed(1) + "s …";
        setTimeout(tic, 80);
      };
      tic();
    });
  }

  // ---------- Interface ----------
  const el = (balise, attributs = {}, ...enfants) => {
    const e = document.createElement(balise);
    for (const [k, v] of Object.entries(attributs)) {
      if (k.startsWith("on")) e.addEventListener(k.slice(2), v); else if (v !== false) e.setAttribute(k, v);
    }
    e.append(...enfants);
    return e;
  };
  const bouton = (texte, action, attributs = {}) => el("button", { type: "button", onclick: action, ...attributs }, texte);
  const PERIME = "Dockerfile, fichier ou cache modifié : reconstruisez.";
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
      cache.size ? el("ul", { class: "cache" }, ...liste) : el("p", { class: "mention" }, "Vide : aucune couche construite."));
  }

  function dessiner() {
    const total = instructions.filter(etape).length;
    let k = 0;
    const dockerfile = el("ol", { class: "dockerfile" }, ...instructions.map((instruction, i) => {
      const [classe, statut, detail] = lecture(affiche ? dernier[i] : null, i);
      return el("li", { class: classeLigne(i, classe) },
        el("span", { class: "numero" }, etape(instruction) ? `[${++k}/${total}]` : ""),
        el("input", {
          type: "text", value: instruction, spellcheck: "false", "aria-label": `Instruction ${i + 1}`, disabled: enCours && "",
          oninput: ev => { instructions[i] = ev.target.value; perimer(); },
        }),
        bouton("↑", () => echanger(i, i - 1), { "aria-label": `Monter l’instruction ${i + 1}`, disabled: (enCours || i < 2) && "" }),
        bouton("↓", () => echanger(i, i + 1), { "aria-label": `Descendre l’instruction ${i + 1}`, disabled: (enCours || i === 0 || i === instructions.length - 1) && "" }),
        el("span", { class: "statut" }, statut),
        el("span", { class: "detail" }, detail),
      );
    }));
    const contexte = el("div", { class: "contexte" }, ...Object.keys(fichiers).map(nom => el("label", {},
      el("code", {}, nom),
      el("input", { type: "text", value: fichiers[nom], spellcheck: "false", disabled: enCours && "",
        oninput: ev => { fichiers[nom] = ev.target.value; perimer(); } }),
    )));
    const commandes = el("div", { class: "commandes" },
      bouton(enCours ? "Passer l’attente" : "docker image build", () => construire(false), { class: "principal" }),
      bouton("avec --no-cache", () => construire(true), { "aria-label": "docker image build --no-cache", disabled: enCours && "" }),
      bouton("Vider le cache", () => modifier(() => cache.clear()), { title: "docker builder prune", disabled: enCours && "" }),
      el("label", { class: "sans-attente" },
        el("input", { type: "checkbox", checked: sansAttente && "", onchange: ev => { sansAttente = ev.target.checked; } }), "sans attente"),
    );
    const zero = bouton("Remettre à zéro", () => {
      ({ instructions, fichiers } = depart()); cache.clear(); historique.length = 0; dernier = precedent = null; affiche = false; erreur = null; dessiner();
    }, { class: "zero", disabled: enCours && "" });

    const h = historique.at(-1);
    const gain = h ? h.complet - h.duree : 0;
    const bilan = el("p", { class: erreur ? "bilan erreur" : "bilan", role: "status", "aria-live": "polite" },
      erreur ? "ERROR : " + erreur
        : enCours ? "Build en cours…"
        : !h ? "Lancez un premier build."
        : !affiche ? PERIME
        : `Build n° ${historique.length} : ${secondes(h.duree)}` + (h.sansCache ? ", cache ignoré (--no-cache)."
          : gain > 0.05 ? ` au lieu de ${secondes(h.complet)} : ${secondes(gain)} gagnées grâce au cache.`
          : ", rien n’était en cache."));
    // Les derniers builds en barres : la longueur dit la durée, la classe dit ce que le cache a épargné.
    const reference = Math.max(...historique.map(b => b.complet), 1);
    const builds = el("ol", { class: "historique" }, ...historique.slice(-4).map((b, i) => {
      const part = b.complet ? b.duree / b.complet : 0;
      const barre = el("span", { class: "barre" });
      barre.style.width = Math.max(1.5, 100 * b.duree / reference) + "%";
      return el("li", { class: part > 0.95 ? "complet" : part < 0.05 ? "gagne" : "partiel" },
        el("span", { class: "rang" }, "n° " + (Math.max(0, historique.length - 4) + i + 1)),
        el("span", { class: "piste" }, barre),
        el("span", { class: "temps" }, secondes(b.duree)));
    }));

    racine.replaceChildren(
      el("section", { class: "zone-dockerfile" }, el("h2", {}, "Dockerfile, et ce que le dernier build en a fait"), zero, dockerfile),
      el("section", { class: "zone-contexte" }, el("h2", {}, "Contexte de build : les fichiers"), contexte,
        el("p", { class: "mention" }, `Simulation : durées fictives, jouées ${ACCELERATION} fois plus vite ; clés simplifiées. Modifiez les instructions ; les flèches les déplacent.`)),
      el("section", { class: "zone-build" }, el("h2", {}, "Construire"), commandes, bilan, builds),
      el("section", { class: "zone-cache" }),
    );
    dessinerCache();
  }
  dessiner();
})();
