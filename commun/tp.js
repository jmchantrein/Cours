// tp.js — comportements des pages web : variante d’affichage, terminaux, copie des commandes.
(() => {
  // Variante d’affichage : choisie par le lecteur, mémorisée dans son navigateur.
  const choix = document.getElementById("variante");
  const appliquer = v => { document.documentElement.dataset.variante = v; choix.value = v; };
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
      const texte = code.dataset.commandes ?? code.textContent;
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
})();
