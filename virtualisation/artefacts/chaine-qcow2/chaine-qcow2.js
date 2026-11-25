// chaine-qcow2.js — simulateur de « qcow2 : copie sur écriture et chaîne d'images », selon le modèle du cours
// (diapos <qcow2-backing> et <backing-file>, avec leurs notes) :
// - un disque qcow2 est découpé en grappes (clusters) de 64 Kio ; une grappe jamais écrite ne prend pas de place ;
// - une image s'appuie sur une image de base (backing file), qui reste en lecture seule ;
// - écrire : la grappe va dans l'image visée (copie sur écriture) ; lire : la grappe est cherchée dans l'image du haut,
//   puis dans chaque image de base en descendant la chaîne ; introuvable, elle vaut zéro ;
// - `qemu-img commit` reverse les grappes d'une image dans sa base et la vide ; `qemu-img rebase` change de base ;
// - danger : écrire dans une image dont d'autres dépendent change ce que celles-ci lisent.
// Le disque est réduit à 16 grappes (1 Mio) ; une grappe est entière, remplie d'un octet répété (le « motif »).
// Occupation sur l'hôte (longueur du fichier, ce que `ls -s` arrondit au bloc) : 196 Kio de métadonnées, 64 Kio par grappe
// propre, et 64 Kio de table L2 dès la première grappe allouée. `commit` vide l'image : QEMU 8.2 réécrit alors ses
// métadonnées (256 Kio au lieu de 196, table L2 libérée). Ces nombres sont ceux de QEMU 8.2 pour un disque de 1 Mio :
// verifier-qemu-img.js les confronte aux vrais outils.
// `rebase` est celui par défaut (« sûr ») : il copie dans l'image les grappes qu'elle ne lirait plus à l'identique ;
// `rebase -u` (sans copie) n'est pas simulé.
// Le simulateur (la partie pure, sans DOM) est confronté à qemu-img et qemu-io par verifier-qemu-img.js.
// Les explications sont calculées à partir du résultat de la simulation, jamais écrites d'avance.
(() => {
  // ---------- Le modèle (fonctions pures) ----------
  const GRAPPES = 16, KIO_GRAPPE = 64, KIO_META = 196, KIO_L2 = 64, KIO_META_VIDEE = 256, MAX_IMAGES = 4;
  const MOTIFS = [0xaa, 0xbb, 0xcc, 0xdd, 0xee];
  const hex = m => m.toString(16).padStart(2, "0");
  const BASE = "base.qcow2";

  const depart = () => ({ suivant: 1, images: [{ nom: BASE, base: null, grappes: {}, zeros: {}, l2: false, videe: false }] });
  const copie = etat => structuredClone(etat);
  const image = (etat, nom) => etat.images.find(i => i.nom === nom);
  const chaine = (etat, nom) => { const c = []; for (let i = image(etat, nom); i; i = i.base && image(etat, i.base)) c.push(i.nom); return c; };
  const descendants = (etat, nom) => etat.images.filter(i => i.nom !== nom && chaine(etat, i.nom).includes(nom)).map(i => i.nom);
  const profondeur = (etat, nom) => chaine(etat, nom).length - 1;
  const rang = nom => nom === BASE ? 0 : +nom.match(/^vm(\d+)/)[1];
  const nbPropres = i => Object.keys(i.grappes).length + Object.keys(i.zeros).length;
  const occupation = (etat, nom) => { const i = image(etat, nom); return (i.videe ? KIO_META_VIDEE : KIO_META) + KIO_GRAPPE * Object.keys(i.grappes).length + (i.l2 ? KIO_L2 : 0); };

  // Où se trouve la grappe k, vue depuis `nom` : l'image qui la fournit (null : introuvable, elle vaut zéro).
  function lireGrappe(etat, nom, k) {
    const parcours = [];
    for (const n of chaine(etat, nom)) {
      parcours.push(n);
      const i = image(etat, n), m = i.grappes[k] ?? (i.zeros[k] ? 0 : undefined);
      if (m !== undefined) return { fournisseur: n, motif: m, parcours };
    }
    return { fournisseur: null, motif: 0, parcours };
  }
  const vue = (etat, nom) => Array.from({ length: GRAPPES }, (_, k) => lireGrappe(etat, nom, k));
  // Les grappes dont le contenu lu diffère entre deux états, pour chaque image qui existe dans les deux.
  function changements(avant, apres, exclues = []) {
    const liste = [];
    for (const { nom } of avant.images) {
      if (exclues.includes(nom) || !image(apres, nom)) continue;
      for (let k = 0; k < GRAPPES; k++) {
        const a = lireGrappe(avant, nom, k).motif, b = lireGrappe(apres, nom, k).motif;
        if (a !== b) liste.push({ image: nom, grappe: k, avant: a, apres: b });
      }
    }
    return liste;
  }

  // Applique une opération ; rend le résultat (nouvel état, détails). L'état reçu n'est jamais modifié.
  //   { op: "creer", base }                    qemu-img create -b base -F qcow2 vmN.qcow2
  //   { op: "ecrire", image, grappe, nombre, motif }   qemu-io -c "write -P motif offset taille"
  //   { op: "lire", image, grappe }            qemu-io -c "read -P …"
  //   { op: "commit", image }                  qemu-img commit image
  //   { op: "rebase", image, base }            qemu-img rebase -b base -F qcow2 image (base null : -b "")
  function appliquer(avant, op) {
    const etat = copie(avant);
    const r = { op: op.op, avant, etat, erreur: null, ...op };
    const refus = texte => { r.erreur = texte; r.etat = copie(avant); return r; };
    if (op.op !== "creer" && !image(etat, op.image)) return refus(`image inconnue : ${op.image}`);
    if (op.op === "rebase" && op.sansCopie) {   // rebase -u : change la base sans rien copier ; non simulé, l'état reste tel quel
      r.limite = `rebase -u change la base sans copier aucune grappe : ce que lit ${op.image} dépendrait de la nouvelle base, et QEMU ne vérifie rien. L'opération n'est pas simulée ; l'image reste telle quelle`;
      return r;
    }

    if (op.op === "creer") {
      if (!image(etat, op.base)) return refus(`image de base inconnue : ${op.base}`);
      if (etat.images.length >= MAX_IMAGES) return refus(`le simulateur gère ${MAX_IMAGES} images au plus`);
      r.nom = `vm${etat.suivant++}.qcow2`;
      etat.images.push({ nom: r.nom, base: op.base, grappes: {}, zeros: {}, l2: false, videe: false });
      r.occupation = occupation(etat, r.nom);
      r.vue = vue(etat, r.nom);
    } else if (op.op === "ecrire") {
      const nombre = op.nombre ?? 1, i = image(etat, op.image);
      if (op.grappe < 0 || op.grappe + nombre > GRAPPES) return refus("hors du disque");
      r.nombre = nombre;
      r.occupationAvant = occupation(avant, op.image);
      for (let k = op.grappe; k < op.grappe + nombre; k++) { i.grappes[k] = op.motif; delete i.zeros[k]; }
      i.l2 = true;
      r.occupation = occupation(etat, op.image);
      const dependantes = descendants(etat, op.image);
      r.touche = changements(avant, etat, [op.image]);
      r.masque = [];       // une grappe écrite que la copie sur écriture cache à une image dépendante
      for (const d of dependantes) for (let k = op.grappe; k < op.grappe + nombre; k++) {
        const f = lireGrappe(etat, d, k).fournisseur;
        if (f !== op.image) r.masque.push({ image: d, grappe: k, par: f });
      }
      r.dependantes = dependantes;
      r.etrangeres = etat.images.map(x => x.nom).filter(n => n !== op.image && !dependantes.includes(n) && !chaine(etat, op.image).includes(n));
    } else if (op.op === "lire") {
      Object.assign(r, lireGrappe(etat, op.image, op.grappe));
    } else if (op.op === "commit") {
      const i = image(etat, op.image);
      if (!i.base) return refus("Image does not have a backing file");
      const dest = image(etat, i.base);
      r.dest = dest.nom;
      r.copiees = [...Object.keys(i.grappes), ...Object.keys(i.zeros)].map(Number).sort((a, b) => a - b);
      r.occupationAvant = { [i.nom]: occupation(avant, i.nom), [dest.nom]: occupation(avant, dest.nom) };
      for (const k of r.copiees) {
        if (i.grappes[k] !== undefined) { dest.grappes[k] = i.grappes[k]; delete dest.zeros[k]; } else { dest.zeros[k] = true; delete dest.grappes[k]; }
      }
      if (r.copiees.length) dest.l2 = true;
      i.grappes = {}; i.zeros = {}; i.l2 = false; i.videe = true;
      r.occupationApres = { [i.nom]: occupation(etat, i.nom), [dest.nom]: occupation(etat, dest.nom) };
      r.touche = changements(avant, etat);
    } else if (op.op === "rebase") {
      const i = image(etat, op.image), cible = op.base ?? null;
      if (cible !== null && !image(etat, cible)) return refus(`image de base inconnue : ${cible}`);
      if (cible !== null && (cible === op.image || descendants(etat, op.image).includes(cible)))
        return refus(`${cible} s'appuie sur ${op.image} : la chaîne ferait une boucle`);
      r.ancienne = i.base;
      r.occupationAvant = occupation(avant, op.image);
      const lue = vue(avant, op.image);
      i.base = cible;
      r.copiees = [];
      for (let k = 0; k < GRAPPES; k++) {
        if (i.grappes[k] !== undefined || i.zeros[k]) continue;
        if (lireGrappe(etat, op.image, k).motif !== lue[k].motif) {
          // Sans ancienne base, QEMU 8.2 marque la grappe « zéro » (aucune place) ; sinon il écrit une grappe de zéros.
          if (lue[k].motif === 0 && r.ancienne === null) i.zeros[k] = true; else i.grappes[k] = lue[k].motif;
          r.copiees.push(k);
        }
      }
      if (r.copiees.length) i.l2 = true;
      r.occupation = occupation(etat, op.image);
      r.inchange = changements(avant, etat).length === 0;
    } else return refus(`opération inconnue : ${op.op}`);
    return r;
  }

  // ---------- Explications : calculées à partir du résultat ----------
  const s = (n, mot, pluriel = mot + "s") => `${n} ${n > 1 ? pluriel : mot}`;
  const kio = n => `${n} Kio`;
  const liste = ks => ks.join(", ");
  const plage = r => r.nombre > 1 ? (r.nombre === GRAPPES ? `les ${GRAPPES} grappes (1 Mio)` : `les grappes ${r.grappe} à ${r.grappe + r.nombre - 1}`) : `la grappe ${r.grappe}`;
  // « 14 grappes lues dans base.qcow2, 2 dans vm1.qcow2 ; 0 introuvable (zéro) ».
  function resume(v) {
    const par = new Map();
    for (const g of v) par.set(g.fournisseur, (par.get(g.fournisseur) ?? 0) + 1);
    const morceaux = [...par].filter(([f]) => f).sort((a, b) => b[1] - a[1]).map(([f, n], i) => i === 0 ? `${s(n, "grappe")} lue${n > 1 ? "s" : ""} dans ${f}` : `${n} dans ${f}`);
    const zero = par.get(null) ?? 0;
    return morceaux.length ? `${morceaux.join(", ")}${zero ? `, ${zero} ${zero > 1 ? "valent" : "vaut"} zéro (écrite${zero > 1 ? "s" : ""} nulle part)` : ""}` : `les ${GRAPPES} grappes valent zéro : rien n'est écrit dans la chaîne`;
  }
  function groupesChangement(touche) {
    const par = new Map();
    for (const c of touche) { if (!par.has(c.image)) par.set(c.image, []); par.get(c.image).push(c); }
    return [...par].map(([nom, cs]) => `${nom} lit autre chose : ${cs.map(c => `grappe ${c.grappe}, ${hex(c.avant)} devient ${hex(c.apres)}`).join(" ; ")}.`);
  }

  function expliquer(r) {
    const p = [];
    if (r.erreur) {
      if (r.op === "commit") p.push(`Impossible : ${r.image} n'a pas d'image de base, rien où reverser (qemu-img : « ${r.erreur} »).`);
      else p.push(`Impossible : ${r.erreur}.`);
      return p;
    }
    const e = r.etat;
    if (r.limite) { p.push(`Limitation du simulateur : ${r.limite}.`); return p; }
    if (r.op === "creer") {
      p.push(`${r.nom} est créée adossée à ${r.base} (qemu-img create -b ${r.base} -F qcow2) : aucune grappe propre, ${kio(r.occupation)} de métadonnées.`);
      p.push(`Tout ce qu'elle lit vient de la chaîne : ${resume(r.vue)}.`);
    } else if (r.op === "ecrire") {
      const i = image(e, r.image);
      p.push(`Écriture de l'octet ${hex(r.motif)} dans ${plage(r)} de ${r.image} : ${i.base ? `la grappe est rangée dans ${r.image}, l'image visée (copie sur écriture), pas dans ${i.base}, qui reste intacte` : `${r.image} n'a pas d'image de base : elle range la grappe chez elle`}.`);
      p.push(`${r.image} occupe maintenant ${kio(r.occupation)} (${s(nbPropres(i), "grappe")} propre${nbPropres(i) > 1 ? "s" : ""}) contre ${kio(r.occupationAvant)} avant.`);
      if (r.touche.length) {
        p.push(...groupesChangement(r.touche));
        p.push(`Danger : ${r.image} sert de base à ${r.dependantes.join(", ")} ; sa grappe a changé sous leurs pieds, et leurs disques deviennent incohérents.`);
      }
      const masque = r.masque;
      if (masque.length) p.push(...[...new Set(masque.map(m => m.image))].map(n => {
        const ms = masque.filter(m => m.image === n);
        return `${n} ne voit pas ${ms.length > 1 ? "ces changements" : "ce changement"} (grappe ${liste(ms.map(m => m.grappe))}) : ${ms.every(m => m.par === ms[0].par) ? (ms[0].par ? `elle la lit dans ${ms[0].par}, plus haut dans la chaîne` : "") : "une image plus haute fournit la grappe"}.`;
      }));
      if (r.etrangeres.length && !r.touche.length) p.push(`${r.etrangeres.join(", ")} ne dépend${r.etrangeres.length > 1 ? "ent" : ""} pas de ${r.image} : ${r.etrangeres.length > 1 ? "elles lisent" : "elle lit"} comme avant.`);
    } else if (r.op === "lire") {
      const trace = r.parcours.map(n => `${n} ${n === r.fournisseur ? "la contient" : "ne l'a pas"}`).join(", puis ");
      p.push(`Lecture de la grappe ${r.grappe} depuis ${r.image} : ${trace}.`);
      p.push(r.fournisseur ? `${r.fournisseur} la fournit : octet ${hex(r.motif)}.` : `Introuvable dans toute la chaîne : elle vaut zéro (octet 00), sans rien occuper.`);
    } else if (r.op === "commit") {
      const [nom, dest] = [r.image, r.dest];
      p.push(r.copiees.length ? `commit : les ${s(r.copiees.length, "grappe")} propre${r.copiees.length > 1 ? "s" : ""} de ${nom} (${liste(r.copiees)}) sont reversée${r.copiees.length > 1 ? "s" : ""} dans ${dest}.`
        : `${nom} n'a aucune grappe propre : il n'y a rien à reverser dans ${dest}.`);
      p.push(`${nom} est vidée et reste adossée à ${dest} : ${kio(r.occupationApres[nom])} contre ${kio(r.occupationAvant[nom])} (QEMU réécrit ses métadonnées : ${KIO_META_VIDEE} Kio, à 4 Kio près selon le système de fichiers) ; ${dest} passe de ${kio(r.occupationAvant[dest])} à ${kio(r.occupationApres[dest])}.`);
      const propre = r.touche.filter(c => c.image === nom), chezDest = r.touche.filter(c => c.image === dest), autres = r.touche.filter(c => c.image !== nom && c.image !== dest);
      p.push(propre.length ? `Défaut : ${nom} ne lit plus les mêmes données.` : `Ce que lit ${nom} n'a pas changé : ses grappes sont maintenant lues dans ${dest}.`);
      if (chezDest.length) p.push(`${dest} lit maintenant ${chezDest.map(c => `${hex(c.apres)} à la grappe ${c.grappe} (${hex(c.avant)} avant)`).join(", ")} : c'est ce que ${nom} lui a reversé.`);
      if (autres.length) { p.push(...groupesChangement(autres)); p.push(`Danger : ${dest} a changé, et ${[...new Set(autres.map(c => c.image))].join(", ")} en dépend${new Set(autres.map(c => c.image)).size > 1 ? "ent" : ""}.`); }
    } else if (r.op === "rebase") {
      const i = image(e, r.image);
      p.push(`${r.image} s'appuyait sur ${r.ancienne ?? "aucune image"} ; elle s'appuie sur ${r.base ?? "aucune image"} (qemu-img rebase ${r.base ? `-b ${r.base} -F qcow2` : '-b ""'}).`);
      if (r.copiees.length) {
        const zeros = r.copiees.filter(k => i.zeros[k] || i.grappes[k] === 0), sansPlace = r.copiees.filter(k => i.zeros[k]);
        p.push(`Pour qu'elle lise les mêmes données, qemu-img copie dans ${r.image} les ${s(r.copiees.length, "grappe")} que l'ancienne chaîne fournissait autrement (${liste(r.copiees)})${zeros.length ? `, dont ${s(zeros.length, "écrite")} comme des zéros : la nouvelle chaîne y lit autre chose que zéro${sansPlace.length ? `${sansPlace.length === zeros.length ? "" : ` (${sansPlace.length} sans place`}${sansPlace.length === zeros.length ? " ; sans ancienne base, QEMU les marque « zéro » : aucune place occupée" : ")"}` : ""}` : ""}.`);
      } else p.push(`La nouvelle chaîne fournit déjà les mêmes données : aucune grappe à copier.`);
      p.push(`${r.image} occupe ${kio(r.occupation)} contre ${kio(r.occupationAvant)} avant. ${r.inchange ? `Ce qu'elle lit n'a pas changé.` : `Défaut : ce qu'elle lit a changé.`}`);
    }
    return p;
  }

  if (typeof module !== "undefined") module.exports = { depart, appliquer, expliquer, vue, lireGrappe, chaine, descendants, occupation, image, profondeur, rang, hex, GRAPPES, MOTIFS, KIO_GRAPPE, KIO_META, KIO_L2, KIO_META_VIDEE, MAX_IMAGES, BASE };
  if (typeof document === "undefined") return;

  // ---------- Interface ----------
  const { el, bouton, recettes } = Artefact;   // création d'éléments et moteur de recettes : commun/artefact.js
  const racine = document.getElementById("artefact");
  const PHASE = 450;         // en ms : chaque moment d'une opération (l'effet, puis les tailles) se voit passer
  const PAUSE = 1100;        // en ms : entre deux étapes d'une recette qui s'enchaîne sans pause
  const COULEURS = ["notion", "pratique", "avertissement", "invite", "distant"];   // une couleur par image (rang)
  const couleur = nom => COULEURS[rang(nom) % COULEURS.length];
  const court = nom => nom === BASE ? "B" : String(rang(nom));

  let sim = depart();
  let choix = { image: BASE, grappe: 0, motif: 0xaa, cible: "" };
  let derniere = [];         // les phrases de la dernière opération
  let signal = new Set();    // les cases (image:grappe) que la dernière opération vient de changer
  let phase = 2;             // 1 : l'effet sur les grappes ; 2 : tailles et explication
  let tailles = null;        // en phase 1, les tailles d'avant
  let tour = 0;              // numéro de l'opération : une opération abandonnée s'y reconnaît

  // ---------- Dessin ----------
  const ordre = () => [...sim.images].sort((a, b) => profondeur(sim, b.nom) - profondeur(sim, a.nom) || rang(a.nom) - rang(b.nom));
  function ligneImage(i) {
    const v = vue(sim, i.nom), n = nbPropres(i), cible = tailles?.[i.nom];
    const cases = v.map((g, k) => {
      const propre = g.fournisseur === i.nom;
      const classes = ["case", g.fournisseur ? `de-${couleur(g.fournisseur)}` : "zero", propre ? "propre" : "", k === choix.grappe ? "choisie" : "", signal.has(`${i.nom}:${k}`) ? "signale" : ""].filter(Boolean).join(" ");
      const texte = g.fournisseur ? hex(g.motif) : "00";
      const lieu = g.fournisseur ? (propre ? "grappe propre à cette image" : `lue dans ${g.fournisseur}`) : "écrite nulle part : zéro";
      return el("button", { type: "button", class: classes, "data-grappe": k, "data-image": i.nom, "aria-label": `${i.nom}, grappe ${k} : ${texte}, ${lieu}`, title: `${i.nom} · grappe ${k} · ${lieu}`,
        disabled: moteur.fige() && "",
        onclick: () => { choix.image = i.nom; choix.grappe = k; dessiner(); } },
        el("span", { class: "octet" }, texte), el("span", { class: "tag" }, g.fournisseur ? (propre ? court(g.fournisseur) : `↓${court(g.fournisseur)}`) : "·"));
    });
    return el("div", { class: `image c-${couleur(i.nom)}${i.nom === choix.image ? " selectionnee" : ""}`, "data-image": i.nom },
      el("button", { type: "button", class: "nom", disabled: moteur.fige() && "", "aria-pressed": String(i.nom === choix.image), onclick: () => { choix.image = i.nom; dessiner(); } },
        el("code", {}, i.nom), el("small", {}, i.base ? `s'appuie sur ${i.base}` : "image de base")),
      el("p", { class: "taille" }, el("b", {}, kio(cible ?? occupation(sim, i.nom))), el("small", {}, `${n} propre${n > 1 ? "s" : ""}`)),
      el("div", { class: "cases" }, ...cases));
  }
  function dessiner() {
    if (!sim.images.some(i => i.nom === choix.image)) choix.image = BASE;
    // images de la barre de commandes
    const choisie = choix.image, desc = descendants(sim, choisie);
    const cibles = sim.images.map(i => i.nom).filter(n => n !== choisie && !desc.includes(n));
    if (choix.cible !== "" && !cibles.includes(choix.cible)) choix.cible = "";
    const fige = moteur.fige();
    racine.querySelector("[data-cle=image]").replaceChildren(...sim.images.map(i => el("option", { value: i.nom }, i.nom)));
    racine.querySelector("[data-cle=image]").value = choisie;
    const cib = racine.querySelector("[data-cle=cible]");
    cib.replaceChildren(el("option", { value: "" }, "aucune (aplatir)"), ...cibles.map(n => el("option", { value: n }, n)));
    cib.value = choix.cible;
    racine.querySelector("[data-cle=grappe]").value = String(choix.grappe);
    racine.querySelector("[data-cle=motif]").value = String(choix.motif);
    racine.querySelector("[data-cle=sansCopie]").checked = !!choix.sansCopie;
    for (const c of racine.querySelectorAll("[data-cle]")) c.disabled = fige;
    const b = nom => racine.querySelector(`[data-action=${nom}]`);
    for (const nom of ["ecrire", "tout", "lire", "adosser", "rebase", "commit"]) b(nom).disabled = fige;
    b("commit").disabled = fige || !image(sim, choisie).base;
    b("adosser").disabled = fige || sim.images.length >= MAX_IMAGES;
    for (const z of racine.querySelectorAll(".zero-bouton")) z.disabled = false;
    b("commit").title = image(sim, choisie).base ? "" : `${choisie} n'a pas d'image de base`;
    b("adosser").title = sim.images.length >= MAX_IMAGES ? `le simulateur gère ${MAX_IMAGES} images au plus` : "";
    // l'index des grappes
    racine.querySelector(".index").replaceChildren(...Array.from({ length: GRAPPES }, (_, k) => el("span", { class: k === choix.grappe ? "choisie" : "" }, String(k))));
    racine.querySelector(".images").replaceChildren(...ordre().map(ligneImage));
    racine.querySelector(".explication-texte").replaceChildren(...(phase < 2 ? ["…"] : derniere).map(f => el("p", { class: /^(Danger|Défaut|Impossible)/.test(f) ? "danger" : f.startsWith("Limitation") ? "limite" : "" }, f)));
  }
  const descriptionOp = op => ({
    creer: `Créer une image adossée à ${op.base}`, ecrire: `Écrire ${hex(op.motif)} dans ${op.image}`, lire: `Lire la grappe ${op.grappe} depuis ${op.image}`,
    commit: `commit de ${op.image}`, rebase: `rebase de ${op.image}`,
  })[op.op];

  // Joue une opération : l'effet sur les grappes d'abord, les tailles et l'explication ensuite.
  async function jouer(op) {
    const r = appliquer(sim, op);
    const moi = ++tour;
    signal = new Set();
    if (!r.erreur) {
      sim = r.etat;
      if (op.op === "ecrire") for (let k = op.grappe; k < op.grappe + (op.nombre ?? 1); k++) signal.add(`${op.image}:${k}`);
      if (op.op === "commit") for (const k of r.copiees) signal.add(`${r.dest}:${k}`);
      if (op.op === "rebase") for (const k of r.copiees ?? []) signal.add(`${op.image}:${k}`);
      for (const c of r.touche ?? []) signal.add(`${c.image}:${c.grappe}`);
      if (op.op === "lire") for (const n of r.parcours) signal.add(`${n}:${op.grappe}`);
      if (op.op === "creer") choix.image = r.nom;
    }
    derniere = expliquer(r);
    phase = 1; tailles = Object.fromEntries(r.avant.images.map(i => [i.nom, occupation(r.avant, i.nom)]));
    dessiner();
    await moteur.attendre(PHASE);
    if (moi !== tour) return null;
    phase = 2; tailles = null; dessiner();
    return derniere;
  }
  async function enchainer(ops) {
    const phrases = [];
    for (const op of ops) { const o = typeof op === "function" ? op() : op; const f = await jouer(o); if (f === null) return []; phrases.push(...f); }
    derniere = phrases; dessiner();
    return phrases;
  }
  // Une opération du lecteur à la main : jouée, puis expliquée dans le cadre.
  const mainLibre = async op => { await jouer(op); moteur.libre(derniere); };

  // ---------- Contrôles ----------
  const menu = (cle, etiquette, options, onchange) => el("select", { "data-cle": cle, "aria-label": etiquette, onchange: ev => onchange(ev.target.value) },
    ...options.map(([v, t]) => el("option", { value: v }, t)));
  function construire() {
    racine.replaceChildren(
      el("section", { class: "zone-commandes" },
        el("div", { class: "titre-zone" }, el("h2", {}, "Commandes"),
          bouton("Remettre à zéro", () => { moteur.fermer(); tour++; sim = depart(); choix = { image: BASE, grappe: 0, motif: 0xaa, cible: "" }; derniere = []; signal = new Set(); phase = 2; tailles = null; dessiner(); }, { class: "zero-bouton" })),
        el("div", { class: "commandes" },
          el("div", { class: "rangee" },
            el("label", {}, el("span", { class: "champ" }, "image"), menu("image", "Image visée", [], v => { choix.image = v; dessiner(); })),
            el("label", {}, el("span", { class: "champ" }, "grappe"), menu("grappe", "Grappe visée", Array.from({ length: GRAPPES }, (_, k) => [String(k), String(k)]), v => { choix.grappe = +v; dessiner(); })),
            el("label", {}, el("span", { class: "champ" }, "octet"), menu("motif", "Octet écrit", MOTIFS.map(m => [String(m), `0x${hex(m)}`]), v => { choix.motif = +v; dessiner(); })),
            bouton("Écrire la grappe", () => mainLibre({ op: "ecrire", image: choix.image, grappe: choix.grappe, nombre: 1, motif: choix.motif }), { "data-action": "ecrire", title: "qemu-io -c \"write -P octet décalage 64k\"" }),
            bouton("Écrire 1 Mio", () => mainLibre({ op: "ecrire", image: choix.image, grappe: 0, nombre: GRAPPES, motif: choix.motif }), { "data-action": "tout", title: "qemu-io -c \"write -P octet 0 1M\"" }),
            bouton("Lire la grappe", () => mainLibre({ op: "lire", image: choix.image, grappe: choix.grappe }), { "data-action": "lire", title: "qemu-io -c \"read -P …\"" })),
          el("div", { class: "rangee" },
            bouton("Adosser une image", () => mainLibre({ op: "creer", base: choix.image }), { "data-action": "adosser", title: "qemu-img create -b image -F qcow2" }),
            bouton("commit", () => mainLibre({ op: "commit", image: choix.image }), { "data-action": "commit", title: "qemu-img commit image" }),
            bouton("rebase sur", () => mainLibre({ op: "rebase", image: choix.image, base: choix.cible || null, sansCopie: choix.sansCopie }), { "data-action": "rebase", title: "qemu-img rebase -b cible -F qcow2 image" }),
            el("label", {}, menu("cible", "Nouvelle image de base du rebase", [], v => { choix.cible = v; dessiner(); })),
            el("label", { class: "option" }, el("input", { type: "checkbox", "data-cle": "sansCopie", onchange: ev => { choix.sansCopie = ev.target.checked; dessiner(); } }), el("code", {}, "-u"))))),
      el("section", { class: "zone-images cadre" },
        el("div", { class: "entete-images" }, el("h2", {}, "Images, vues depuis chacune"), el("div", { class: "index", "aria-hidden": "true" })),
        el("div", { class: "images" }),
        el("p", { class: "mention" }, "Case : l'octet lu, et l'image qui le fournit (B = base, 1 = vm1…). Trait plein : grappe propre ; ↓ : lue plus bas ; · : zéro. La case -u (rebase sans copie) n'est pas simulée.")),
      el("section", { class: "zone-explication cadre" }, el("h2", {}, "Ce que dit le résultat"),
        el("div", { class: "explication-texte", role: "status", "aria-live": "polite" })));
  }

  // ---------- Recettes ----------
  const base1M = () => [{ op: "ecrire", image: BASE, grappe: 0, nombre: GRAPPES, motif: 0xaa }];
  const adosser = base => () => ({ op: "creer", base });
  const ecrire = (image, grappe, motif, nombre = 1) => ({ op: "ecrire", image, grappe, nombre, motif });
  const lire = (image, grappe) => ({ op: "lire", image, grappe });
  // Chaque étape de recette part de l'état courant ; la première remet la simulation à son départ.
  const remise = () => { sim = depart(); choix = { image: BASE, grappe: 0, motif: 0xaa, cible: "" }; derniere = []; signal = new Set(); };
  const etape = (...ops) => async () => enchainer(ops);
  const premiere = (...ops) => async () => { remise(); return enchainer(ops); };
  const RECETTES = {
    "ecriture-cow": [
      ["Créer base.qcow2 et y écrire l'octet 0xaa dans 1 Mio (les 16 grappes).", premiere(...base1M())],
      ["Créer vm1.qcow2 adossée à base.qcow2.", etape(adosser(BASE))],
      ["Écrire 0xbb dans la grappe 0 de vm1.qcow2.", etape(ecrire("vm1.qcow2", 0, 0xbb))],
      ["Lire la grappe 5 depuis vm1.qcow2.", etape(lire("vm1.qcow2", 5))],
    ],
    "vm-de-plus": [
      ["Créer base.qcow2 et y écrire l'octet 0xaa dans 1 Mio.", premiere(...base1M())],
      ["Créer vm1.qcow2 adossée à base.qcow2.", etape(adosser(BASE))],
      ["Créer vm2.qcow2, adossée elle aussi à base.qcow2.", etape(adosser(BASE))],
      ["Écrire 0xcc dans la grappe 3 de vm2.qcow2.", etape(ecrire("vm2.qcow2", 3, 0xcc))],
    ],
    "danger-base": [
      ["Créer base.qcow2 (0xaa dans 1 Mio), puis vm1.qcow2 et vm2.qcow2 adossées à elle.", premiere(...base1M(), adosser(BASE), adosser(BASE))],
      ["Écrire 0xbb dans la grappe 0 de vm1.qcow2.", etape(ecrire("vm1.qcow2", 0, 0xbb))],
      ["Écrire 0xdd dans la grappe 0 de base.qcow2.", etape(ecrire(BASE, 0, 0xdd))],
      ["Écrire 0xdd dans la grappe 5 de base.qcow2.", etape(ecrire(BASE, 5, 0xdd))],
    ],
    "chaine-commit": [
      ["Créer base.qcow2 (0xaa dans 1 Mio) ; créer vm1.qcow2 adossée à base.qcow2 et y écrire 0xbb dans la grappe 1.", premiere(...base1M(), adosser(BASE), ecrire("vm1.qcow2", 1, 0xbb))],
      ["Créer vm2.qcow2 adossée à vm1.qcow2 et y écrire 0xcc dans la grappe 2.", etape(adosser("vm1.qcow2"), ecrire("vm2.qcow2", 2, 0xcc))],
      ["Lire les grappes 0, 1 et 2 depuis vm2.qcow2.", etape(lire("vm2.qcow2", 0), lire("vm2.qcow2", 1), lire("vm2.qcow2", 2))],
      ["commit de vm2.qcow2 dans sa base, vm1.qcow2.", etape({ op: "commit", image: "vm2.qcow2" })],
    ],
    "rebase": [
      ["Créer base.qcow2 (0xaa dans 1 Mio) ; vm1.qcow2 adossée à base.qcow2, avec 0xbb dans la grappe 1 ; vm2.qcow2 adossée à vm1.qcow2, avec 0xcc dans la grappe 2.",
        premiere(...base1M(), adosser(BASE), ecrire("vm1.qcow2", 1, 0xbb), adosser("vm1.qcow2"), ecrire("vm2.qcow2", 2, 0xcc))],
      ["rebase de vm2.qcow2 sur base.qcow2, sans passer par vm1.qcow2.", etape({ op: "rebase", image: "vm2.qcow2", base: BASE })],
      ["rebase de vm2.qcow2 sur aucune image (aplatir).", etape({ op: "rebase", image: "vm2.qcow2", base: null })],
    ],
  };
  // L'état de la simulation : mémorisé après chaque étape d'une recette, pour pouvoir y revenir.
  const capturer = () => structuredClone({ sim, choix, derniere, signal: [...signal] });
  function retablir(sauvegarde) {
    tour++;   // une opération en cours d'exécution est abandonnée
    const c = structuredClone(sauvegarde);
    sim = c.sim; choix = c.choix; derniere = c.derniere; signal = new Set(); phase = 2; tailles = null;
    dessiner();
  }
  const moteur = recettes({ recettes: RECETTES, depart: ["Départ : base.qcow2 vient d'être créée (qemu-img create) ; rien n'y est écrit."],
    titreLibre: "Votre opération", pause: () => PAUSE,
    remettre: () => { remise(); phase = 2; tailles = null; dessiner(); }, capturer, retablir, afficher: () => dessiner() });

  construire();
  dessiner();
})();
