// cmd-entrypoint.js — simulateur de « CMD × ENTRYPOINT : la commande lancée », selon le modèle du cours
// (diapo <cmd-entrypoint>, Dockerfile reference « Understand how CMD and ENTRYPOINT interact ») :
// - une instruction en forme exec ["e1", "e2"] est enregistrée telle quelle ; en forme shell (e1 e2), elle l'est
//   sous la forme ["/bin/sh", "-c", "e1 e2"] ;
// - déclarer un ENTRYPOINT remet à vide le CMD hérité de l'image de base (pas celui du Dockerfile lui-même) ;
// - docker container run : les arguments remplacent le CMD ; --entrypoint remplace l'ENTRYPOINT et efface le CMD ;
// - le conteneur exécute ENTRYPOINT puis CMD, mis bout à bout ; sans rien, Docker refuse : « no command specified » ;
// - avec /bin/sh -c « script », les éléments suivants sont $0, $1… de sh : une commande qui ne les emploie pas les ignore ;
//   sh reste PID 1 et ne relaie pas SIGTERM.
//
// Le simulateur (la partie pure, sans DOM) est confronté au vrai Docker par verifier-docker.js : mêmes entrées,
// argv, Config.Entrypoint, Config.Cmd, /proc/1/cmdline et arrêt comparés. Ce qu'il ne sait pas traiter (un script
// shell saisi dans les arguments, un programme qu'il ne connaît pas), il le dit au lieu de répondre.
// Les explications sont calculées à partir du résultat de la simulation, jamais écrites d'avance.
(() => {
  // ---------- Le modèle (fonctions pures) ----------
  const TEXTE_ENTRYPOINT = "e1 e2", TEXTE_CMD = "c1 c2";
  const PROGRAMMES = ["e1", "e3", "c1", "x", "bash"];   // les programmes de l'image d'essai (voir verifier-docker.js)
  const BASES = {
    bash: { nom: "debian:13", cmd: ["bash"] },           // debian:13 déclare CMD ["bash"]
    vide: { nom: "base-vide", cmd: null },               // une image sans ENTRYPOINT ni CMD
  };
  const ORIGINES = { entrypoint: "ENTRYPOINT", cmd: "CMD", herite: "CMD hérité", arguments: "arguments de run", option: "--entrypoint" };
  const depart = () => ({ base: "bash", entrypoint: "exec", cmd: "exec", option: "", args: "" });

  // Une instruction du Dockerfile, telle que Docker l'enregistre : un tableau de mots, chacun avec son origine.
  const enregistrer = (texte, forme, origine) => forme === "exec"
    ? texte.split(" ").map(mot => ({ mot, origine }))
    : ["/bin/sh", "-c", texte].map(mot => ({ mot, origine }));
  const mots = liste => (liste ?? []).map(x => x.mot);
  const json = liste => liste && liste.length ? JSON.stringify(mots(liste)) : "null";

  function simuler(e) {
    const base = BASES[e.base];
    // Ce que le build enregistre dans l'image (docker image inspect).
    const entrypointImage = e.entrypoint === "absent" ? null : enregistrer(TEXTE_ENTRYPOINT, e.entrypoint, "entrypoint");
    let cmdImage, heritage;
    if (e.cmd !== "absent") { cmdImage = enregistrer(TEXTE_CMD, e.cmd, "cmd"); heritage = "propre"; }
    else if (entrypointImage) { cmdImage = null; heritage = base.cmd ? "efface" : "aucun"; }
    else if (base.cmd) { cmdImage = base.cmd.map(mot => ({ mot, origine: "herite" })); heritage = "herite"; }
    else { cmdImage = null; heritage = "aucun"; }
    // Ce que docker container run en fait (docker container inspect).
    const option = e.option.trim(), arguments_ = e.args.trim() ? e.args.trim().split(/\s+/) : [];
    const entrypointConteneur = option ? [{ mot: option, origine: "option" }] : entrypointImage;
    const cmdConteneur = arguments_.length ? arguments_.map(mot => ({ mot, origine: "arguments" })) : option ? null : cmdImage;
    const argv = [...(entrypointConteneur ?? []), ...(cmdConteneur ?? [])];
    const r = {
      entree: { ...e }, base: base.nom, heritage,
      image: { entrypoint: entrypointImage, cmd: cmdImage },
      conteneur: { entrypoint: entrypointConteneur, cmd: cmdConteneur },
      argv, erreur: null, genre: null, pid1: null, programme: null, ignores: [], limites: [],
    };
    if (!argv.length) { r.erreur = "no command specified"; return r; }

    // Qui est lancé, et qui porte le PID 1 : avec /bin/sh -c, c'est sh ; sinon, le premier mot.
    const m = mots(argv);
    if (m[0] === "/bin/sh" && m[1] === "-c" && m.length >= 3) {
      r.genre = "shell";
      r.pid1 = m;
      if (["entrypoint", "cmd"].includes(argv[2].origine)) {
        const script = argv[2].mot.split(" ");
        r.programme = { nom: script[0], args: script.slice(1) };
        r.ignores = argv.slice(3);
      } else r.limites.push("le simulateur n’interprète pas un script shell saisi dans les arguments ou l’option --entrypoint : il ne peut pas dire ce que sh en ferait");
    } else {
      r.genre = "programme";
      r.pid1 = m;
      r.programme = { nom: m[0], args: m.slice(1) };
    }
    if (r.programme && !PROGRAMMES.includes(r.programme.nom)) {
      r.limites.push(`« ${r.programme.nom} » n’est pas un programme de l’image d’essai (${PROGRAMMES.join(", ")}) : le simulateur ne sait pas si Docker le trouverait ; sans lui, il échoue avec « executable file not found in $PATH »`);
      r.programme = null; r.pid1 = null;
    }
    return r;
  }

  // ---------- Explications : calculées à partir du résultat ----------
  const guillemets = mot => /\s/.test(mot) ? `« ${mot} »` : mot;
  const ligne = liste => mots(liste).map(guillemets).join(" ");
  function expliquer(r) {
    const e = r.entree, p = [];
    const ic = r.image.cmd, ie = r.image.entrypoint;
    if (r.erreur) {
      p.push(`Docker refuse de créer le conteneur : « ${r.erreur} ».`);
      p.push(`Rien à lancer : ni ENTRYPOINT ni CMD dans l’image${e.base === "vide" ? " ni dans sa base" : ""}, ni argument, ni --entrypoint.`);
      return p;
    }
    // La composition d'argv, origine par origine.
    const groupes = [];
    for (const x of r.argv) {
      const dernier = groupes.at(-1);
      if (dernier && dernier.origine === x.origine) dernier.liste.push(x); else groupes.push({ origine: x.origine, liste: [x] });
    }
    p.push(`Le conteneur exécute ${r.argv.length} élément${r.argv.length > 1 ? "s" : ""} : ${groupes.map(g => `${ligne(g.liste)} (${ORIGINES[g.origine]})`).join(" puis ")}.`);
    // Qui a remplacé quoi.
    const args = r.conteneur.cmd?.[0]?.origine === "arguments" ? r.conteneur.cmd : null;
    if (e.option.trim()) {
      p.push(`--entrypoint ${e.option.trim()} remplace l’ENTRYPOINT de l’image (${ie ? ligne(ie) : "aucun"})` + (ic ? ` et efface son CMD (${ligne(ic)}).` : ". L’image n’a pas de CMD à effacer.")
        + (args ? ` Les arguments « ${ligne(args)} » sont alors les seuls paramètres.` : ""));
    } else if (args) {
      p.push(ic ? `Les arguments « ${ligne(args)} » remplacent le CMD de l’image (${ligne(ic)}${r.heritage === "herite" ? ", hérité de " + r.base : ""}) ; l’ENTRYPOINT reste.`
        : ie ? `Les arguments « ${ligne(args)} » s’ajoutent à l’ENTRYPOINT : l’image n’a pas de CMD à remplacer.`
        : `L’image n’a ni ENTRYPOINT ni CMD : les arguments « ${ligne(args)} » sont la commande.`);
    }
    if (r.heritage === "herite" && !args && !e.option.trim()) {
      p.push(`Le Dockerfile ne déclare ni CMD ni ENTRYPOINT : le CMD ${JSON.stringify(mots(ic))} vient de l’image de base ${r.base}.`);
    } else if (r.heritage === "efface") {
      p.push(`${r.base} déclare CMD ${JSON.stringify(BASES[e.base].cmd)} ; déclarer un ENTRYPOINT remet ce CMD hérité à vide : Config.Cmd de l’image vaut null.`);
    }
    // Forme shell : les éléments qui suivent le script deviennent $0, $1…
    if (r.genre === "shell" && r.programme) {
      const origine = ORIGINES[r.argv[2].origine];
      p.push(`${origine} en forme shell : enregistré sous la forme /bin/sh -c « ${r.argv[2].mot} » ; sh lance ${r.programme.nom}${r.programme.args.length ? ` avec ${r.programme.args.length > 1 ? "les paramètres" : "le paramètre"} ${r.programme.args.join(" ")}` : ""}.`);
      if (r.ignores.length) {
        const noms = r.ignores.map((x, i) => `${guillemets(x.mot)} = $${i}`).join(", ");
        p.push(`${r.ignores.length > 1 ? "Les éléments suivants deviennent des paramètres" : "L’élément suivant devient un paramètre"} de sh (${noms}) que « ${r.argv[2].mot} » n’emploie pas : ${r.programme.nom} ne ${r.ignores.length > 1 ? "les" : "le"} reçoit pas.`);
      }
    }
    // Un CMD en forme shell derrière un ENTRYPOINT qui n'est pas en forme shell : ses trois éléments deviennent des paramètres.
    if (r.genre === "programme" && r.argv.some((x, i) => i > 0 && x.mot === "/bin/sh" && x.origine === "cmd")) {
      p.push(`Le CMD en forme shell est enregistré comme ["/bin/sh","-c",${JSON.stringify(TEXTE_CMD)}] : derrière l’ENTRYPOINT, ce sont trois paramètres de ${r.programme.nom}, qui ne lance aucun shell.`);
    }
    // PID 1 et signaux.
    if (r.pid1) {
      if (r.genre === "shell") {
        p.push(`PID 1 est /bin/sh -c, pas ${r.programme.nom} : sh ne relaie pas SIGTERM ; docker container stop attend 10 s, puis SIGKILL (137).`);
      } else {
        p.push(`PID 1 est ${r.programme.nom} lui-même : il reçoit SIGTERM ; s’il le gère, l’arrêt est immédiat (code 0), sinon il attend 10 s.`);
      }
    }
    for (const l of r.limites) p.push(`Limitation du simulateur : ${l}.`);
    return p;
  }

  if (typeof module !== "undefined") module.exports = { simuler, expliquer, depart, PROGRAMMES, BASES, TEXTE_ENTRYPOINT, TEXTE_CMD };
  if (typeof document === "undefined") return;

  // ---------- Interface ----------
  const { el, bouton, recettes } = Artefact;   // création d'éléments et moteur de recettes : commun/artefact.js
  const racine = document.getElementById("artefact");
  const PAUSE = 1100;        // en ms : entre deux étapes d'une recette qui s'enchaîne sans pause
  const PHASE = 500;         // en ms : chaque moment d'un lancement (Dockerfile, argv, PID 1) se voit passer

  let etat = depart();
  let phase = 3;             // 0 : rien d'affiché ; 1 : ce que Docker enregistre ; 2 : argv ; 3 : PID 1 et explication
  let tour = 0;              // numéro du lancement : un lancement annulé s'y reconnaît

  // ---------- Dessin des résultats ----------
  const motDe = x => el("span", { class: `mot origine-${x.origine}`, title: ORIGINES[x.origine] },
    el("code", {}, /\s/.test(x.mot) ? `"${x.mot}"` : x.mot), el("small", {}, ORIGINES[x.origine]));
  const absent = (texte = "…") => el("p", { class: "vide" }, texte);

  function dessinerResultats() {
    const r = simuler(etat);
    const ph = phase;
    const cadre = (cible, ...contenu) => racine.querySelector(cible).replaceChildren(...contenu);

    // 1. Ce que Docker enregistre.
    cadre(".zone-inspect",
      el("h2", {}, "Ce que Docker enregistre"),
      ph < 1 ? absent() : el("div", { class: "inspect" },
        el("p", { class: "commande" }, "docker image inspect · Config"),
        el("p", { class: "valeur" }, el("span", { class: "champ" }, "Entrypoint"), el("code", {}, json(r.image.entrypoint))),
        el("p", { class: "valeur" }, el("span", { class: "champ" }, "Cmd"), el("code", {}, json(r.image.cmd))),
        el("p", { class: "commande" }, "docker container inspect · Config"),
        el("p", { class: "valeur" }, el("span", { class: "champ" }, "Entrypoint"), el("code", {}, json(r.conteneur.entrypoint))),
        el("p", { class: "valeur" }, el("span", { class: "champ" }, "Cmd"), el("code", {}, json(r.conteneur.cmd)))));

    // 2. Ce que le conteneur exécute : argv, chaque mot avec son origine.
    cadre(".zone-argv",
      el("h2", {}, "Ce que le conteneur exécute (argv)"),
      ph < 2 ? absent() : r.erreur
        ? el("p", { class: "erreur" }, "Error response from daemon: " + r.erreur)
        : el("div", {},
          el("p", { class: "mots" }, ...r.argv.map(motDe)),
          el("p", { class: "mention" }, `Path = premier mot, Args = les suivants. Simulation : le Dockerfile écrit toujours ${TEXTE_ENTRYPOINT} et ${TEXTE_CMD} ; programmes de l’image d’essai : ${PROGRAMMES.join(", ")}.`)));

    // 3. PID 1.
    cadre(".zone-pid1",
      el("h2", {}, "PID 1"),
      ph < 3 ? absent() : r.erreur ? el("p", { class: "vide" }, "Aucun processus : le conteneur n'est pas créé.")
        : r.pid1
          ? el("div", { class: "pid1 " + r.genre },
            el("p", { class: "qui" }, r.genre === "shell" ? "/bin/sh -c" : r.programme.nom, el("small", {}, r.genre === "shell" ? "le shell, pas le programme" : "le programme lui-même")),
            el("p", { class: "commande" }, "/proc/1/cmdline"),
            el("p", {}, el("code", {}, JSON.stringify(r.pid1))),
            el("p", { class: "programme" }, el("span", { class: "champ" }, `${r.programme?.nom ?? "le programme"} reçoit`), el("code", {}, r.programme ? JSON.stringify(r.programme.args) : "?")))
          : el("p", { class: "limite" }, "Limitation du simulateur : " + r.limites.join(" ; ") + "."));

    // Explication.
    const phrases = ph < 3 ? ["…"] : expliquer(r);
    cadre(".zone-explication",
      el("h2", {}, "Ce que dit le résultat"),
      el("div", { class: "explication-texte", role: "status", "aria-live": "polite" },
        ...phrases.map(f => el("p", { class: f.startsWith("Limitation") ? "limite" : f.startsWith("Docker refuse") ? "erreur" : "" }, f))));
  }

  // ---------- Contrôles : créés une fois, relus par `appliquer` ----------
  const modifie = () => { phase = 3; appliquer(); dessinerResultats(); aLaMain(); };
  const aLaMain = () => moteur.libre(expliquer(simuler(etat)));
  const selecteur = (cle, options, etiquette) => el("select", { "aria-label": etiquette, "data-cle": cle,
    onchange: ev => { etat[cle] = ev.target.value; modifie(); } },
    ...options.map(([valeur, texte]) => el("option", { value: valeur }, texte)));
  const champ = (cle, etiquette, placeholder) => el("input", { type: "text", spellcheck: "false", "aria-label": etiquette, "data-cle": cle, placeholder,
    oninput: ev => { etat[cle] = ev.target.value; modifie(); } });
  const FORMES = [["absent", "absent"], ["exec", "forme exec"], ["shell", "forme shell"]];

  function construire() {
    const dockerfile = el("div", { class: "dockerfile", role: "group", "aria-label": "Dockerfile" },
      el("div", { class: "ligne" }, el("span", { class: "mot-cle" }, "FROM"), selecteur("base", [["bash", "debian:13 (CMD [\"bash\"])"], ["vide", "base-vide (ni CMD ni ENTRYPOINT)"]], "Image de base")),
      el("div", { class: "ligne" }, el("span", { class: "mot-cle" }, "ENTRYPOINT"), selecteur("entrypoint", FORMES, "Ligne ENTRYPOINT"), el("code", { class: "texte", "data-ligne": "entrypoint" })),
      el("div", { class: "ligne" }, el("span", { class: "mot-cle" }, "CMD"), selecteur("cmd", FORMES, "Ligne CMD"), el("code", { class: "texte", "data-ligne": "cmd" })));
    const lancement = el("div", { class: "lancement", role: "group", "aria-label": "docker container run" },
      el("p", { class: "ligne-commande" }, el("span", { class: "invite" }, "$"), el("code", {}, "docker container run")),
      el("label", { class: "ligne" }, el("code", { class: "mot-cle" }, "--entrypoint"), champ("option", "Option --entrypoint", "ex. e3")),
      el("label", { class: "ligne" }, el("code", { class: "mot-cle" }, "image"), champ("args", "Arguments de docker container run, après le nom de l’image", "ex. x y")));
    racine.replaceChildren(
      el("section", { class: "zone-dockerfile" },
        el("div", { class: "titre-zone" }, el("h2", {}, "Dockerfile"),
          bouton("Remettre à zéro", () => { moteur.fermer(); etat = depart(); phase = 3; appliquer(); dessinerResultats(); }, { class: "zero" })),
        dockerfile),
      el("section", { class: "zone-run" }, el("div", { class: "titre-zone" }, el("h2", {}, "Lancement")), lancement),
      el("section", { class: "zone-argv cadre" }),
      el("section", { class: "zone-inspect cadre" }),
      el("section", { class: "zone-pid1 cadre" }),
      el("section", { class: "zone-explication cadre" }));
  }
  // Remet les contrôles d'accord avec l'état, et bloque la saisie pendant une recette.
  function appliquer() {
    for (const c of racine.querySelectorAll("[data-cle]")) {
      if (c.value !== etat[c.dataset.cle]) c.value = etat[c.dataset.cle];
      c.disabled = moteur.fige();
    }
    const e = etat;
    const texte = (forme, t) => forme === "absent" ? "(ligne absente)" : forme === "exec" ? JSON.stringify(t.split(" ")).replace(/","/g, '", "') : t;
    racine.querySelector("[data-ligne=entrypoint]").textContent = texte(e.entrypoint, TEXTE_ENTRYPOINT);
    racine.querySelector("[data-ligne=cmd]").textContent = texte(e.cmd, TEXTE_CMD);
    for (const b of racine.querySelectorAll(".zero")) b.disabled = false;
  }
  const modifierEtat = changements => {
    Object.assign(etat, changements);
    appliquer();
  };

  // ---------- Recettes : les manipulations des expériences, jouées pas à pas ----------
  const NOMS = { base: "l’image de base", entrypoint: "la ligne ENTRYPOINT", cmd: "la ligne CMD", option: "--entrypoint", args: "les arguments de run" };
  const VALEURS = { bash: "debian:13", vide: "base-vide", absent: "absente", exec: "en forme exec", shell: "en forme shell" };
  const valeur = (cle, v) => cle === "option" || cle === "args" ? (v.trim() ? `« ${v.trim()} »` : "vides") : VALEURS[v];
  // Une action de recette règle les contrôles, puis lance : elle rend l'explication de ce qui vient de se passer.
  const regler = changements => async () => {
    const decrits = [];
    for (const [cle, v] of Object.entries(changements)) {
      if (etat[cle] !== v) decrits.push(`${NOMS[cle][0].toUpperCase() + NOMS[cle].slice(1)} : ${valeur(cle, etat[cle])} → ${valeur(cle, v)}.`);
    }
    const moi = ++tour;
    phase = 0; modifierEtat(changements); dessinerResultats();
    for (const cle of Object.keys(changements)) racine.querySelector(`[data-cle=${cle}]`)?.classList.add("signale");
    for (const p of [1, 2, 3]) {
      await moteur.attendre(PHASE);
      if (moi !== tour) return [];
      phase = p; dessinerResultats();
    }
    for (const c of racine.querySelectorAll(".signale")) c.classList.remove("signale");
    return [...(decrits.length ? [decrits.join(" ")] : []), ...expliquer(simuler(etat))];
  };
  const DEPART = { base: "bash", entrypoint: "exec", cmd: "exec", option: "", args: "" };
  const RECETTES = {
    "arguments-de-run": [
      ["ENTRYPOINT et CMD en forme exec ; lancer sans argument.", regler({ ...DEPART })],
      ["Lancer avec les arguments x y.", regler({ args: "x y" })],
    ],
    "forme-shell": [
      ["ENTRYPOINT en forme shell, CMD en forme exec ; lancer.", regler({ ...DEPART, entrypoint: "shell" })],
      ["Lancer avec les arguments x y.", regler({ args: "x y" })],
      ["ENTRYPOINT en forme exec, sans argument ; lancer.", regler({ entrypoint: "exec", args: "" })],
    ],
    "cmd-en-forme-shell": [
      ["ENTRYPOINT et CMD en forme exec ; lancer.", regler({ ...DEPART })],
      ["CMD en forme shell ; lancer.", regler({ cmd: "shell" })],
      ["Sans ligne ENTRYPOINT ; lancer.", regler({ entrypoint: "absent" })],
    ],
    "cmd-herite": [
      ["Base debian:13, sans ENTRYPOINT ni CMD ; lancer.", regler({ ...DEPART, entrypoint: "absent", cmd: "absent" })],
      ["Ajouter ENTRYPOINT en forme exec ; lancer.", regler({ entrypoint: "exec" })],
      ["Base sans commande, sans ENTRYPOINT ; lancer.", regler({ base: "vide", entrypoint: "absent" })],
    ],
    "option-entrypoint": [
      ["ENTRYPOINT et CMD en forme exec ; lancer sans argument.", regler({ ...DEPART })],
      ["Lancer avec --entrypoint e3, sans argument.", regler({ option: "e3" })],
      ["Lancer avec --entrypoint e3 et les arguments x y.", regler({ args: "x y" })],
    ],
  };
  // L'état de la simulation : mémorisé après chaque étape d'une recette, pour pouvoir y revenir.
  const capturer = () => structuredClone({ etat });
  function retablir(sauvegarde) {
    tour++;   // un lancement en cours d'exécution est abandonné
    etat = structuredClone(sauvegarde.etat); phase = 3;
    for (const c of racine.querySelectorAll(".signale")) c.classList.remove("signale");
    appliquer(); dessinerResultats();
  }
  const moteur = recettes({ recettes: RECETTES, depart: ["Départ : debian:13, ENTRYPOINT et CMD en forme exec, aucun argument."],
    titreLibre: "Votre lancement", pause: () => PAUSE,
    remettre: () => { etat = depart(); phase = 3; dessinerResultats(); }, capturer, retablir, afficher: appliquer });

  construire();
  appliquer();
  dessinerResultats();
})();
