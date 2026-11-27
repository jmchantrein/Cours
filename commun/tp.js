// tp.js — comportements des pages web : variante d’affichage, terminaux, copie des commandes,
// sommaire qui suit la lecture, expériences pas à pas, questions « prédisez » des pages de cours.
(() => {
  document.documentElement.classList.add("js");
  // Variante d’affichage : choisie par le lecteur, mémorisée dans son navigateur.
  const choix = document.getElementById("variante");
  const appliquer = v => {
    document.documentElement.dataset.variante = v; choix.value = v;
    // Schémas et illustrations : un dessin par palette, on montre celui qui sert cette variante.
    for (const dessin of document.querySelectorAll("[data-pour]")) {
      dessin.hidden = !dessin.dataset.pour.split(" ").includes(v);
    }
  };
  try { appliquer(localStorage.getItem("variante") || "projection"); } catch { appliquer("projection"); }
  choix.addEventListener("change", () => {
    appliquer(choix.value);
    try { localStorage.setItem("variante", choix.value); } catch { /* stockage indisponible : choix non mémorisé */ }
  });

  // Terminaux : l’invite `$ ` et les commentaires `# ` sont mis en évidence. Sur une page qui déclare un
  // terminal (page-web(terminal: …)), chaque commande reçoit un bouton « Exécuter », que terminal.js relie.
  // Dans une question « prédisez » (page de cours), la sortie est masquée jusqu’à ce que la commande soit exécutée.
  const executable = Boolean(document.body.dataset.terminal);
  for (const code of document.querySelectorAll(".terminal pre code")) {
    const lignes = code.textContent.split("\n");
    const cmds = commandes(lignes);
    code.dataset.commandes = cmds.map(c => c.texte).join("\n");
    const finDe = new Map(cmds.map(c => [c.fin, c.texte]));
    const deCommande = new Set(cmds.flatMap(c => Array.from({ length: c.texte.split("\n").length }, (_, k) => c.fin - k)));
    const masquer = Boolean(code.closest(".predire"));
    // Dans un indice ou un corrigé replié, « Écrire » dépose aussi la commande à l’invite, sans la valider :
    // l’étudiant la relit, la complète, appuie sur Entrée.
    const replie = Boolean(code.closest("details"));
    code.replaceChildren(...lignes.flatMap((ligne, i) => {
      const fin = i < lignes.length - 1 ? "\n" : "";
      const apres = executable && finDe.has(i)
        ? [executer(finDe.get(i)), ...(replie && !finDe.get(i).includes("\n") ? [ecrire(finDe.get(i))] : []), fin] : [fin];
      if (ligne.startsWith("$ ")) return [span("invite", "$ "), ligne.slice(2), ...apres];
      if (ligne.startsWith("# ")) return [span("commentaire", ligne + fin)];
      if (masquer && !deCommande.has(i)) return [span("sortie-masquee", ligne + fin)];
      return [ligne, ...apres];
    }));
  }
  for (const question of document.querySelectorAll(".predire")) {
    const voir = document.createElement("button");
    voir.type = "button"; voir.className = "predire-voir"; voir.textContent = "Voir la sortie sans exécuter";
    voir.addEventListener("click", () => { question.dataset.revele = ""; });
    question.querySelector(".terminal")?.after(voir);
  }
  // Une commande exécutée dans le terminal (terminal.js) dévoile la sortie annoncée de sa question.
  document.addEventListener("terminal-commande", e => {
    const question = e.detail.bouton?.closest(".predire");
    if (question) question.dataset.revele = "";
  });
  function executer(commande) {
    const b = document.createElement("button");
    b.type = "button"; b.className = "executer"; b.textContent = "Exécuter";
    b.dataset.commande = commande; b.setAttribute("aria-disabled", "true");
    return b;
  }
  function ecrire(commande) {
    const b = executer(commande);
    b.className = "ecrire"; b.textContent = "Écrire";
    return b;
  }
  function span(classe, texte) {
    const s = document.createElement("span");
    s.className = classe; s.textContent = texte;
    return s;
  }
  // Les commandes d’un terminal : les lignes `$ …`, et leurs suites tant que la commande n’est pas finie :
  // ligne qui finit par `\`, ou guillemet ouvert (programme awk ou sed sur plusieurs lignes). Chaque commande
  // donne son texte et le rang de sa dernière ligne.
  function commandes(lignes) {
    const sortie = [];
    let suite = false;
    lignes.forEach((ligne, i) => {
      if (suite) Object.assign(sortie.at(-1), { texte: sortie.at(-1).texte + "\n" + ligne, fin: i });
      else if (ligne.startsWith("$ ")) sortie.push({ texte: ligne.slice(2), fin: i });
      else return;
      suite = inacheve(sortie.at(-1).texte);
    });
    return sortie;
  }
  // Vrai si le texte attend une suite : il finit par `\`, ou un guillemet reste ouvert (un `#` en début de mot
  // commence un commentaire, jusqu’à la fin de la ligne).
  function inacheve(texte) {
    if (texte.endsWith("\\")) return true;
    let guillemet = null;
    for (let i = 0; i < texte.length; i++) {
      const c = texte[i];
      if (guillemet === "'") { if (c === "'") guillemet = null; }
      else if (guillemet === '"') { if (c === "\\") i++; else if (c === '"') guillemet = null; }
      else if (c === "\\") i++;
      else if (c === "'" || c === '"') guillemet = c;
      else if (c === "#" && (i === 0 || /\s/.test(texte[i - 1]))) while (i < texte.length && texte[i] !== "\n") i++;
    }
    return guillemet !== null;
  }

  // Bouton « Copier » : les commandes d’un terminal, ou le fichier entier.
  if (navigator.clipboard) {
    for (const pre of document.querySelectorAll("pre")) {
      const code = pre.querySelector("code");
      const texte = code.dataset.commandes || code.textContent;
      if (!texte) continue;
      const bouton = document.createElement("button");
      bouton.type = "button"; bouton.className = "copier"; bouton.textContent = "Copier";
      bouton.addEventListener("click", async () => {
        await navigator.clipboard.writeText(texte);
        bouton.textContent = "Copié";
        setTimeout(() => { bouton.textContent = "Copier"; }, 1500);
      });
      pre.append(bouton);
    }
  }

  // Hauteur du bandeau, pour ce qui reste en vue juste dessous (la colonne d’une page de cours).
  const bandeau = document.querySelector(".bandeau");
  const mesurer = () => document.documentElement.style.setProperty("--bandeau-h", bandeau.offsetHeight + "px");
  if (bandeau) { mesurer(); new ResizeObserver(mesurer).observe(bandeau); }   // le bouton « Terminal » s’y ajoute ensuite

  // Sommaire : l’étape en cours de lecture est marquée, et une barre montre l’avancement dans la page.
  const sommaire = document.querySelector('nav[role="doc-toc"]');
  if (sommaire) {
    const liens = [...sommaire.querySelectorAll("a[href^='#']")];
    const titres = liens.map(a => document.getElementById(decodeURIComponent(a.hash.slice(1))));
    const barre = document.createElement("div");
    barre.className = "avancement";
    document.querySelector(".bandeau").append(barre);
    const suivre = () => {
      const seuil = innerHeight * 0.3;
      let courant = 0;
      titres.forEach((t, i) => { if (t && t.getBoundingClientRect().top < seuil) courant = i; });
      liens.forEach((a, i) => a.setAttribute("aria-current", i === courant ? "true" : "false"));
      const hauteur = document.documentElement.scrollHeight - innerHeight;
      barre.style.transform = `scaleX(${hauteur > 0 ? Math.min(1, scrollY / hauteur) : 0})`;
    };
    addEventListener("scroll", suivre, { passive: true });
    addEventListener("resize", suivre);
    suivre();
  }

  // Expériences guidées : une à la fois, avec « Précédente » et « Suivante ».
  for (const groupe of document.querySelectorAll(".experiences")) {
    const experiences = [...groupe.querySelectorAll(".experience")];
    if (experiences.length < 2) continue;
    let courante = 0;
    const bouton = (texte, pas) => {
      const b = document.createElement("button");
      b.type = "button"; b.textContent = texte;
      b.addEventListener("click", () => { courante += pas; montrer(); });
      return b;
    };
    const precedente = bouton("←", -1), suivante = bouton("→", 1);
    precedente.setAttribute("aria-label", "Expérience précédente");
    suivante.setAttribute("aria-label", "Expérience suivante");
    const rang = document.createElement("span");
    rang.setAttribute("aria-live", "polite");
    const nav = document.createElement("div");
    nav.className = "experiences-nav";
    nav.append(precedente, rang, suivante);
    groupe.prepend(nav);
    groupe.classList.add("pas-a-pas");
    const montrer = () => {
      experiences.forEach((e, i) => { e.hidden = i !== courante; });
      rang.textContent = `Expérience ${courante + 1} sur ${experiences.length}`;
      precedente.disabled = courante === 0;
      suivante.disabled = courante === experiences.length - 1;
    };
    montrer();
  }
})();
