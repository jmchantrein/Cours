// cache-de-build.js — simulateur du cache de build, selon le modèle du cours :
// clé d’une étape = empreinte de (clé du parent + instruction + contenu du fichier copié) ;
// cache de build : clé → couche. Une étape dont la clé est connue est réutilisée (CACHED).
(() => {
  const racine = document.getElementById("artefact");

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
  const cache = new Set();   // les clés connues : chacune désigne une couche déjà construite
  const historique = [];     // un élément par build : { duree, executees, sansCache }
  let dernier = null;        // les étapes du dernier build, pour dire pourquoi une étape est rejouée
  let affiche = false;       // le résultat du dernier build correspond-il encore au Dockerfile affiché ?
  let erreur = null;

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

  function construire(sansCache) {
    erreur = null; affiche = false;
    if (mot(instructions[0]) !== "FROM") { erreur = "Un Dockerfile commence par une instruction FROM."; return dessiner(); }
    const cacheVide = cache.size === 0;
    const etapes = [];
    let parent = "";
    for (const [i, brute] of instructions.entries()) {
      const instruction = brute.trim();
      let source = null, contenu = "";
      if (copie(instruction)) {
        source = instruction.split(/\s+/)[1];
        if (!(source in fichiers)) {
          erreur = `${mot(instruction)} : « ${source ?? ""} » n’est pas dans le contexte de build.`;
          return dessiner();
        }
        contenu = fichiers[source];
      }
      const cle = empreinte([parent, instruction, contenu].join("\n"));
      const avant = dernier?.[i];
      const executee = i > 0 && etape(instruction) && (sansCache || !cache.has(cle));
      let raison = "";
      if (executee) {
        raison = sansCache ? "option --no-cache : le cache n’est pas consulté"
          : cacheVide ? "le cache est vide"
          : !avant || avant.parent !== parent ? "l’étape précédente a changé : celle-ci n’a plus le même parent"
          : avant.instruction !== instruction ? "l’instruction a changé"
          : avant.contenu !== contenu ? `le contenu de ${source} a changé`
          : "cette clé n’est pas dans le cache";
      }
      etapes.push({ instruction, cle, parent, contenu, executee, raison, duree: executee ? duree(instruction) : 0 });
      cache.add(cle);
      parent = cle;
    }
    dernier = etapes; affiche = true;
    historique.push({
      duree: etapes.reduce((somme, e) => somme + e.duree, 0),
      executees: etapes.filter(e => e.executee).length,
      sansCache,
    });
    dessiner();
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
  // Toute modification rend le dernier résultat caduc : il s’efface jusqu’au prochain build.
  const modifier = action => { action(); affiche = false; erreur = null; dessiner(); };
  // Pendant la saisie, le résultat s’efface sur place : redessiner retirerait le champ des mains du lecteur.
  const PERIME = "Dockerfile, fichier ou cache modifié : reconstruisez.";
  function perimer() {
    if (!affiche && !erreur) return;
    affiche = false; erreur = null;
    for (const e of racine.querySelectorAll(".dockerfile .statut, .dockerfile .detail")) e.textContent = "";
    for (const li of racine.querySelectorAll(".dockerfile li")) li.className = "";
    const bilan = racine.querySelector(".bilan");
    bilan.className = "bilan"; bilan.textContent = PERIME;
  }
  const echanger = (i, j) => modifier(() => { [instructions[i], instructions[j]] = [instructions[j], instructions[i]]; });

  function dessiner() {
    // Chaque ligne du Dockerfile porte, à droite, ce que le dernier build en a fait.
    const total = instructions.filter(etape).length;
    let k = 0;
    const dockerfile = el("ol", { class: "dockerfile" }, ...instructions.map((instruction, i) => {
      const e = affiche ? dernier[i] : null;
      const numero = etape(instruction) ? `[${++k}/${total}]` : "";
      const statut = !e ? "" : i === 0 ? "image de base" : !etape(instruction) ? "pas de couche"
        : e.executee ? "DONE " + e.duree.toFixed(1) + "s" : "CACHED";
      return el("li", { class: !e ? "" : e.executee ? "executee" : "reutilisee" },
        el("span", { class: "numero" }, numero),
        el("input", {
          type: "text", value: instruction, spellcheck: "false", "aria-label": `Instruction ${i + 1}`,
          oninput: ev => { instructions[i] = ev.target.value; perimer(); },
        }),
        bouton("↑", () => echanger(i, i - 1), { "aria-label": `Monter l’instruction ${i + 1}`, disabled: i < 2 && "" }),
        bouton("↓", () => echanger(i, i + 1), { "aria-label": `Descendre l’instruction ${i + 1}`, disabled: (i === 0 || i === instructions.length - 1) && "" }),
        el("span", { class: "statut" }, statut),
        el("span", { class: "detail" }, !e ? "" : "clé " + e.cle + (e.raison ? " · rejouée : " + e.raison : "")),
      );
    }));
    const contexte = el("div", { class: "contexte" }, ...Object.keys(fichiers).map(nom => el("label", {},
      el("code", {}, nom),
      el("input", {
        type: "text", value: fichiers[nom], spellcheck: "false",
        oninput: ev => { fichiers[nom] = ev.target.value; perimer(); },
      }),
    )));
    const commandes = el("div", { class: "commandes" },
      bouton("docker image build", () => construire(false), { class: "principal" }),
      bouton("avec --no-cache", () => construire(true), { "aria-label": "docker image build --no-cache" }),
      bouton("Vider le cache", () => modifier(() => cache.clear()), { title: "docker builder prune" }),
    );
    const zero = bouton("Remettre à zéro", () => {
      ({ instructions, fichiers } = depart()); cache.clear(); historique.length = 0; dernier = null; affiche = false; erreur = null; dessiner();
    }, { class: "zero" });
    const h = historique.at(-1);
    const bilan = el("p", { class: erreur ? "bilan erreur" : "bilan", role: "status", "aria-live": "polite" },
      erreur ? "ERROR : " + erreur
        : !h ? "Lancez un premier build."
        : !affiche ? PERIME
        : `Build n° ${historique.length} : ${secondes(h.duree)}, ${h.executees} étape${h.executees > 1 ? "s" : ""} exécutée${h.executees > 1 ? "s" : ""}.`);
    const builds = el("ol", { class: "historique" }, ...historique.slice(-8).map((b, i) =>
      el("li", { value: Math.max(0, historique.length - 8) + i + 1 }, `${secondes(b.duree)}${b.sansCache ? " (--no-cache)" : ""}`)));

    racine.replaceChildren(
      el("section", { class: "zone-dockerfile" }, el("h2", {}, "Dockerfile, et ce que le dernier build en a fait"), zero, dockerfile),
      el("section", { class: "zone-contexte" }, el("h2", {}, "Contexte de build : le contenu des fichiers"), contexte,
        el("p", { class: "mention" }, "Simulation : durées fictives, clés simplifiées. Les instructions se modifient librement ; les flèches les déplacent.")),
      el("section", { class: "zone-build" }, el("h2", {}, "Construire"), commandes, bilan,
        el("p", { class: "compteur" }, `Cache de build : ${cache.size} clé${cache.size > 1 ? "s" : ""}. Durée des builds :`), builds),
    );
  }
  dessiner();
})();
