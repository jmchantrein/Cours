// artefact.js — ce que partagent les artefacts interactifs (voir commun/README.md, « Pages web : artefacts »).
// `artefact(…)` de theme-tp.typ l’embarque avant le script de l’artefact, qui y prend `Artefact` :
//   const { el, bouton, recettes } = Artefact;
// - el(balise, attributs, ...enfants) : crée un élément ; un attribut `onclick` (`on…`) est un écouteur, `false` ou
//   `null` n’écrit rien ;
// - bouton(texte, action, attributs) : un <button type="button"> ;
// - recettes({…}) : le moteur de recettes, décrit plus bas.
const Artefact = (() => {
  const el = (balise, attributs = {}, ...enfants) => {
    const e = document.createElement(balise);
    for (const [k, v] of Object.entries(attributs)) {
      if (k.startsWith("on")) e.addEventListener(k.slice(2), v); else if (v !== false && v != null) e.setAttribute(k, v);
    }
    e.append(...enfants);
    return e;
  };
  const bouton = (texte, action, attributs = {}) => el("button", { type: "button", onclick: action, ...attributs }, texte);
  const dormir = ms => new Promise(fini => setTimeout(fini, ms));

  // Le moteur de recettes. Chaque expérience de la page qui nomme une recette (`experiences(…, "nom")`) reçoit une
  // carte : la liste des étapes, puis un lecteur. Une recette rejoue des manipulations, étape par étape :
  // « Continuer » (ou une case : sans pause), pause au milieu d’une étape, reprise, « Revenir » (même pendant une
  // étape), « Rejouer » à la fin ; à la fin, le lecteur reprend la main.
  // L’artefact décrit :
  //   recettes    { nom: [[titre, action], …] } ; `action` est une fonction async qui agit sur la simulation et rend
  //               les phrases qui expliquent ce qu’elle vient de faire. Le titre dit l’action, pas son résultat.
  //   depart      les phrases affichées avant la première étape.
  //   titreLibre  le titre de l’explication quand le lecteur a repris la main (« Votre build »).
  //   pause       () → ms : le temps de lecture entre deux étapes d’une recette qui s’enchaîne.
  //   remettre    () : remet la simulation à l’état de départ, et l’affiche.
  //   capturer    () → état complet de la simulation, mémorisé après chaque étape (structuredClone).
  //   retablir    (état) : rétablit la simulation et l’affiche ; abandonne aussi l’étape en cours d’exécution.
  //   afficher    () : redessine les commandes de l’artefact, qui se bloquent pendant une recette (`moteur.fige()`).
  // Il rend { fige, libre, fermer, attendre } :
  //   fige()           vrai pendant une recette qui n’est pas finie : le lecteur regarde ;
  //   libre(phrases)   le lecteur a modifié quelque chose à la fin d’une recette : ces phrases l’expliquent ;
  //   fermer()         ferme la recette ouverte, en laissant la simulation dans son état ;
  //   attendre(ms, suivi)  attend `ms` ; une recette en pause gèle l’attente. `suivi(écoulé)` est appelé à chaque
  //                    tic ; s’il rend vrai, l’attente s’arrête.
  function recettes({ recettes: RECETTES, depart, titreLibre, pause, remettre, capturer, retablir, afficher }) {
    // La recette ouverte : { nom, pas (étapes faites), etats et explications (après chaque étape), occupe (une étape
    // s’exécute), gel (elle est en pause), lecture (les étapes s’enchaînent), libre (phrases : le lecteur a repris
    // la main), jeton (annule une étape abandonnée), enBoucle }.
    let recette = null;
    let continu = false;       // les recettes s’enchaînent-elles sans pause entre deux étapes ?
    const etapesDe = r => RECETTES[r.nom];
    const finie = r => r.pas >= etapesDe(r).length && !r.occupe;

    // Abandonne l’étape en cours d’exécution et revient à l’état qui la précédait.
    function annuler(r) {
      r.jeton++; r.occupe = false; r.gel = false;
      retablir(r.etats[r.pas]);
    }
    function ouvrir(nom) {
      if (recette) fermer();
      remettre();
      recette = { nom, pas: 0, etats: [capturer()], explications: [depart],
        occupe: false, gel: false, lecture: continu, libre: null, jeton: 0, enBoucle: false };
      afficher(); majRecettes();
      continu ? defiler(recette) : executer(recette);
    }
    function fermer() {
      if (!recette) return;
      if (recette.occupe) annuler(recette);
      recette = null;
      afficher(); majRecettes();
    }
    // Exécute l’étape suivante, puis mémorise l’état obtenu et son explication.
    async function executer(r) {
      const i = r.pas, jeton = ++r.jeton;
      r.occupe = true; r.libre = null;
      afficher(); majRecettes();
      const explication = await etapesDe(r)[i][1]();
      if (recette !== r || r.jeton !== jeton) return;   // étape annulée par un retour en arrière
      r.pas = i + 1; r.etats[r.pas] = capturer(); r.explications[r.pas] = explication; r.occupe = false; r.gel = false;
      afficher(); majRecettes();
    }
    // Enchaînement sans pause : une étape, le temps de lire, la suivante… tant que la lecture n’est pas suspendue.
    async function defiler(r) {
      r.enBoucle = true;
      while (recette === r && r.lecture) {
        if (r.occupe) { await dormir(80); continue; }   // une étape lancée à la main se termine d’abord
        if (r.pas >= etapesDe(r).length) { r.lecture = false; break; }
        if (r.pas > 0) for (let reste = pause(); reste > 0 && recette === r && r.lecture; reste -= 60) await dormir(60);
        if (recette !== r || !r.lecture || r.occupe) continue;
        await executer(r);
      }
      r.enBoucle = false;
      if (recette === r) { afficher(); majRecettes(); }
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

    // Chaque expérience de la page qui nomme une recette reçoit sa carte : ses étapes, puis son lecteur.
    const cartes = [...document.querySelectorAll(".experience[data-recette]")].filter(c => RECETTES[c.dataset.recette]);
    function majRecettes() {
      for (const carte of cartes) {
        const nom = carte.dataset.recette, r = recette?.nom === nom ? recette : null, etapes = RECETTES[nom], n = etapes.length;
        let bloc = carte.querySelector(".recette");
        if (!bloc) { bloc = el("div", { class: "recette" }); carte.querySelector("details").before(bloc); }
        bloc.classList.toggle("ouverte", !!r);
        bloc.dataset.etat = !r ? "fermee" : finie(r) ? "terminee" : "encours";
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
        const action = rang === 0 ? "Avant la première étape" : `Étape ${rang} sur ${n}` + (fin ? " — terminée : à vous" : "");
        // La recette reste sous les yeux : étapes faites, étape en cours ou qui vient d’être expliquée, étape suivante.
        const etat = i => i === r.pas ? (r.occupe ? "courante" : "prochaine") : i > r.pas ? ""
          : i === r.pas - 1 && !r.occupe && !r.libre ? "faite expliquee" : "faite";
        const explication = r.occupe ? [r.gel ? "En pause, au milieu de l’étape." : "En cours…"] : r.libre ?? r.explications[r.pas];
        const principal = r.occupe ? (r.gel ? "▶ Reprendre" : "❚❚ Pause") : fin ? "↻ Rejouer"
          : continu && r.lecture ? "❚❚ Pause" : r.pas === 0 ? "Commencer ▶" : "Continuer ▶";
        bloc.replaceChildren(
          el("div", { class: "recette-entete" }, el("span", { class: "recette-titre" }, "Recette"), el("span", { class: "recette-rang" }, action),
            bouton("✕", fermer, { class: "fermer", "aria-label": "Fermer la recette", title: "Fermer la recette" })),
          el("ol", { class: "recette-etapes" }, ...etapes.map(([titre], i) =>
            el("li", { class: etat(i), "aria-current": i === (r.occupe ? r.pas : r.pas - 1) ? "step" : false }, titre))),
          el("div", { class: "explication", role: "status", "aria-live": "polite" },
            el("p", { class: "explication-titre" }, r.occupe ? "Ce qui se passe" : r.libre ? titreLibre : "Ce qui vient de se passer"),
            ...explication.map(phrase => el("p", {}, phrase))),
          el("div", { class: "lecteur" },
            bouton("◀ Revenir", reculerRecette, { "aria-label": "Revenir à l’étape précédente", disabled: (r.pas === 0 && !r.occupe) && "" }),
            bouton(principal, avancerRecette, { class: "jouer" }), sansPause));
      }
    }
    // Changer d’expérience ferme la recette ouverte : sa carte ne serait plus visible.
    new MutationObserver(() => { if (recette && cartes.find(c => c.dataset.recette === recette.nom)?.hidden) fermer(); })
      .observe(document.querySelector(".experiences") ?? document.body, { subtree: true, attributes: true, attributeFilter: ["hidden"] });
    majRecettes();

    return {
      fige: () => !!recette && !finie(recette),
      libre(phrases) { if (recette && !recette.occupe) { recette.libre = phrases; majRecettes(); } },
      fermer,
      attendre: (ms, suivi) => new Promise(fini => {
        let ecoule = 0, avant = performance.now();
        const tic = () => {
          const maintenant = performance.now();
          if (!recette?.gel) ecoule += maintenant - avant;
          avant = maintenant;
          if (ecoule >= ms || suivi?.(ecoule)) return fini();
          setTimeout(tic, 60);
        };
        tic();
      }),
    };
  }

  return { el, bouton, recettes };
})();
