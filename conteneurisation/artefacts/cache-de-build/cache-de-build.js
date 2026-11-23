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
  let dernier = null;        // les étapes du dernier build
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
    erreur = null;
    if (mot(instructions[0]) !== "FROM") { erreur = "Un Dockerfile commence par une instruction FROM."; return dessiner(); }
    const cacheVide = cache.size === 0;
    const etapes = [];
    let parent = "";
    for (const [i, brute] of instructions.entries()) {
      const instruction = brute.trim();
      if (!instruction) continue;
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
      const avant = dernier?.[etapes.length];
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
    dernier = etapes;
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
  const echanger = (i, j) => { [instructions[i], instructions[j]] = [instructions[j], instructions[i]]; dessiner(); };

  function dessiner() {
    const dockerfile = el("ol", { class: "dockerfile" }, ...instructions.map((instruction, i) => el("li", {},
      el("input", {
        type: "text", value: instruction, spellcheck: "false", "aria-label": `Instruction ${i + 1}`,
        oninput: e => { instructions[i] = e.target.value; },
      }),
      bouton("↑", () => echanger(i, i - 1), { "aria-label": `Monter l’instruction ${i + 1}`, disabled: i < 2 && "" }),
      bouton("↓", () => echanger(i, i + 1), { "aria-label": `Descendre l’instruction ${i + 1}`, disabled: (i === 0 || i === instructions.length - 1) && "" }),
    )));
    const contexte = el("div", { class: "contexte" }, ...Object.keys(fichiers).map(nom => el("label", {},
      el("code", {}, nom),
      el("input", { type: "text", value: fichiers[nom], spellcheck: "false", oninput: e => { fichiers[nom] = e.target.value; } }),
    )));
    const commandes = el("div", { class: "commandes" },
      bouton("docker image build", () => construire(false), { class: "principal" }),
      bouton("docker image build --no-cache", () => construire(true)),
      bouton("docker builder prune (vider le cache)", () => { cache.clear(); dessiner(); }),
      bouton("Tout remettre à zéro", () => {
        ({ instructions, fichiers } = depart()); cache.clear(); historique.length = 0; dernier = null; erreur = null; dessiner();
      }),
    );

    const sortie = el("div", { class: "sortie", role: "status", "aria-live": "polite" });
    if (erreur) sortie.append(el("p", { class: "erreur" }, "ERROR : " + erreur));
    else if (!dernier) sortie.append(el("p", {}, "Lancez un premier build."));
    else {
      const total = dernier.filter(e => etape(e.instruction)).length;
      let k = 0;
      sortie.append(el("ol", { class: "etapes" }, ...dernier.map((e, i) => {
        const numero = etape(e.instruction) ? `[${++k}/${total}] ` : "";
        const statut = i === 0 ? "image de base"
          : !etape(e.instruction) ? "pas de couche"
          : e.executee ? "DONE " + e.duree.toFixed(1) + "s" : "CACHED";
        return el("li", { class: e.executee ? "executee" : "reutilisee" },
          el("code", { class: "instruction" }, numero + e.instruction),
          el("span", { class: "statut" }, statut),
          el("span", { class: "detail" }, "clé " + e.cle + (e.raison ? " · rejouée : " + e.raison : "")),
        );
      })));
      const h = historique.at(-1);
      sortie.append(el("p", { class: "bilan" },
        `Build n° ${historique.length} : ${secondes(h.duree)}, ${h.executees} étape${h.executees > 1 ? "s" : ""} exécutée${h.executees > 1 ? "s" : ""}.`));
    }
    const builds = el("ol", { class: "historique" }, ...historique.map(h =>
      el("li", {}, `${secondes(h.duree)}${h.sansCache ? " (--no-cache)" : ""}`)));

    racine.replaceChildren(
      el("section", {}, el("h3", {}, "Dockerfile"), dockerfile,
        el("h3", {}, "Contexte de build : le contenu des fichiers"), contexte),
      el("section", {}, el("h3", {}, "Construire"), commandes, sortie,
        el("p", { class: "compteur" }, `Cache de build : ${cache.size} clé${cache.size > 1 ? "s" : ""}. Durée de chaque build :`), builds),
    );
  }
  dessiner();
})();
