// tp.js — comportements des pages web : variante d’affichage, terminaux, copie des commandes,
// sommaire qui suit la lecture, expériences pas à pas.
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

  // Terminaux : l’invite `$ ` et les commentaires `# ` sont mis en évidence.
  for (const code of document.querySelectorAll(".terminal pre code")) {
    const lignes = code.textContent.split("\n");
    code.dataset.commandes = commandes(lignes);
    code.replaceChildren(...lignes.flatMap((ligne, i) => {
      const fin = i < lignes.length - 1 ? "\n" : "";
      if (ligne.startsWith("$ ")) return [span("invite", "$ "), ligne.slice(2) + fin];
      if (ligne.startsWith("# ")) return [span("commentaire", ligne + fin)];
      return [ligne + fin];
    }));
  }
  function span(classe, texte) {
    const s = document.createElement("span");
    s.className = classe; s.textContent = texte;
    return s;
  }
  // Les commandes d’un terminal : les lignes `$ …`, et leurs suites quand elles finissent par `\`.
  function commandes(lignes) {
    const sortie = [];
    let suite = false;
    for (const ligne of lignes) {
      if (ligne.startsWith("$ ")) sortie.push(ligne.slice(2));
      else if (suite) sortie.push(ligne);
      else continue;
      suite = ligne.endsWith("\\");
    }
    return sortie.join("\n");
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
