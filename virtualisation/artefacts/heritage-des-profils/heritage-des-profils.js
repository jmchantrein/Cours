// heritage-des-profils.js — simulateur de l’héritage des profils d’Incus, selon le modèle du cours (diapo
// « Héritage des profils : deux régimes ») : la configuration étendue d’une instance s’obtient en appliquant
// ses profils, dans l’ordre donné, puis l’instance.
// - Clés de configuration : remplacement clé par clé ; le dernier qui définit la clé l’emporte.
// - Périphériques : à nom égal, le dernier remplace le périphérique en entier ; leurs clés ne fusionnent pas.
// Le résultat est ce qu’affiche `incus config show <instance> --expanded`.
//
// Ce que le simulateur affirme est lu dans le code d’Incus 6.0.4, et se confronte à un vrai Incus par verifier-incus.js :
// - ExpandInstanceConfig, ExpandInstanceDevices (internal/server/db/cluster/profiles.go) : la règle ci-dessus ;
// - cmd/incus/config_device.go : `device add` refuse un nom que la couche porte déjà ; `device override` copie dans
//   l’instance le périphérique hérité, puis y pose les clés données ; `device set`, `unset` et `remove` refusent un
//   périphérique que l’instance ne tient que d’un profil ;
// - cmd/incus/profile.go : `profile add` ajoute en fin de liste, `profile assign` remplace la liste ;
// - doProfileUpdate (cmd/incusd/profiles_utils.go) : modifier un profil met à jour aussitôt chaque instance qui l’utilise ;
// - internal/server/device/none.go : un périphérique de type none ne crée rien ; il sert à remplacer un périphérique hérité ;
// - une valeur vide supprime la clé (deviceConfig.NewDevices, ClusterTx.configUpdate) ;
// - la sortie YAML est celle de gopkg.in/yaml.v2 : clés triées, chaînes entre guillemets quand il le faut.
// Ce qu’il ne sait pas simuler (valider une clé ou un périphérique, dire quand une clé prend effet), il le dit au
// lieu de répondre. Les explications sont calculées à partir du résultat, jamais écrites d’avance.
//
// Chaque manipulation s’écrit au terminal en commandes `incus`. Des recettes rejouent, pas à pas, les
// manipulations des expériences de la page : elles tapent la commande, puis l’appliquent.
(() => {
  const racine = document.getElementById("artefact");
  const FRAPPE = 24;         // en ms par caractère : une recette tape sa commande avant de l’appliquer
  const ATTENTE_MIN = 700;   // en ms : même une étape sans commande se voit passer
  const PAUSE = 1400;        // en ms : entre deux étapes d’une recette qui s’enchaîne sans pause
  const JOURNAL_MAX = 40;    // commandes gardées dans le journal

  // L’état : des lignes de texte, comme les arguments des commandes. Une ligne de configuration s’écrit
  // « clé=valeur » (incus config set) ; une ligne de périphérique « nom type clé=valeur… » (incus config device add).
  // Une ligne : { id, t (texte appliqué), b (saisie refusée, gardée sous les yeux), e (le refus) }.
  const depart = () => {
    let n = 0;
    const lignes = (...textes) => textes.map(t => ({ id: ++n, t }));
    // L’exemple des diapos : `incus launch images:debian/13 v2 --vm --profile default --profile moyen --config limits.cpu=4`.
    // S’y ajoutent une seconde instance qui partage le profil moyen, et un profil que personne n’a encore.
    const e = {
      profils: {
        default: { config: [], devices: lignes("eth0 nic network=incusbr0 name=eth0", "root disk path=/ pool=default") },
        moyen: { config: lignes("limits.cpu=2", "limits.memory=2GiB"), devices: lignes("root disk path=/ pool=default size=20GiB") },
        petit: { config: lignes("limits.cpu=1", "limits.memory=1GiB"), devices: [] },
      },
      instances: {
        v2: { profils: ["default", "moyen"], config: lignes("limits.cpu=4"), devices: [] },
        v3: { profils: ["default", "moyen"], config: [], devices: [] },
      },
      courante: "v2",       // l’instance affichée
      journal: [],          // { n, argv, erreur } : les commandes incus équivalentes aux manipulations, numérotées
      commandes: 0,         // nombre de commandes écrites depuis le départ
      bilan: null,          // l’explication de la dernière manipulation
    };
    e.suivant = n;
    return e;
  };
  let etat = depart();
  let generation = 0;        // numéro du dessin : une saisie validée sur un dessin périmé est ignorée
  // La recette ouverte : { nom, pas (étapes faites), etats et explications (après chaque étape), occupe (une étape
  // s’exécute), gel (elle est en pause), lecture (les étapes s’enchaînent), libre (le lecteur a repris la main) }.
  let recette = null;
  let continu = false;       // les recettes s’enchaînent-elles sans pause entre deux étapes ?

  // ---------- Le modèle ----------
  const P = nom => ({ genre: "profil", nom }), I = nom => ({ genre: "instance", nom });
  const meme = (a, b) => a.genre === b.genre && a.nom === b.nom;
  const entite = (e, cible) => (cible.genre === "profil" ? e.profils : e.instances)[cible.nom];
  // Ce qu’est une ligne de configuration : { cle, valeur }, ou un échec.
  function lireCle(texte) {
    const t = texte.trim(), i = t.indexOf("="), mots = t.split(/\s+/);
    // Forme ancienne, encore acceptée pour une seule clé : « incus config set <instance> <clé> <valeur> ».
    if (i < 0 && mots.length === 2) return { cle: mots[0], valeur: mots[1] };
    if (i < 0) return { echec: { genre: "erreur", message: `Error: Invalid key=value configuration: ${mots[0]}` } };
    const cle = t.slice(0, i).trim(), valeur = t.slice(i + 1).trim();
    if (!cle || /\s/.test(cle)) return { echec: { genre: "limite", message: "un nom de clé vide, ou contenant une espace, n’est pas simulé" } };
    return { cle, valeur };
  }
  // Ce qu’est une ligne de périphérique : { nom, cles } (le type est l’une des clés, comme dans le YAML), ou un échec.
  function lirePeripherique(texte) {
    const t = texte.trim();
    if (/["'\\]/.test(t)) return { echec: { genre: "limite", message: "les guillemets et les barres obliques inverses du shell ne sont pas interprétés dans une ligne de périphérique" } };
    const [nom, type, ...reste] = t.split(/\s+/);
    if (!type) return { echec: { genre: "erreur", message: "Error: Invalid number of arguments" } };
    if (nom.includes("=") || type.includes("=")) return { echec: { genre: "limite", message: "une ligne de périphérique commence par son nom, puis son type (nic, disk, proxy, none…) ; les clés viennent ensuite" } };
    const cles = { type };
    for (const mot of reste) {
      const i = mot.indexOf("=");
      if (i < 1) return { echec: { genre: "erreur", mot } };   // le message dépend de la commande : add ou set
      if (i === mot.length - 1) delete cles[mot.slice(0, i)]; else cles[mot.slice(0, i)] = mot.slice(i + 1);
    }
    cles.type ??= type;
    return { nom, cles };
  }
  const ecrirePeripherique = (nom, cles) =>
    [nom, cles.type, ...Object.entries(cles).filter(([k]) => k !== "type").map(([k, v]) => `${k}=${v}`)].join(" ");
  // Une couche (profil ou instance) lue comme Incus la stocke : clé → valeur, nom → périphérique.
  const lireConfig = ent => new Map(ent.config.filter(l => l.t).map(l => Object.values(lireCle(l.t))));
  const lireDevices = ent => new Map(ent.devices.filter(l => l.t).map(l => Object.values(lirePeripherique(l.t))));

  // L’ordre des clés dans la sortie d’Incus : celui de yaml.v2 (sorter.go), alphabétique, les nombres par leur valeur.
  // (Cette comparaison n’est pas transitive pour des noms comme a.01, a.0x et a.1 : leur ordre peut alors différer.)
  function avant(a, b) {
    const ar = [...a], br = [...b], lettre = c => /\p{L}/u.test(c), chiffre = c => /\p{Nd}/u.test(c);
    for (let i = 0; i < ar.length && i < br.length; i++) {
      if (ar[i] === br[i]) continue;
      const al = lettre(ar[i]), bl = lettre(br[i]);
      if (al && bl) return ar[i] < br[i];
      if (al || bl) return bl;
      let an = 0, bn = 0, ai, bi;
      if (ar[i] === "0" || br[i] === "0") for (let j = i - 1; j >= 0 && chiffre(ar[j]); j--) if (ar[j] !== "0") { an = 1; bn = 1; break; }
      for (ai = i; ai < ar.length && chiffre(ar[ai]); ai++) an = an * 10 + Number(ar[ai]);
      for (bi = i; bi < br.length && chiffre(br[bi]); bi++) bn = bn * 10 + Number(br[bi]);
      if (an !== bn) return an < bn;
      if (ai !== bi) return ai < bi;
      return ar[i] < br[i];
    }
    return ar.length < br.length;
  }
  const trier = cles => [...cles].sort((a, b) => (a === b ? 0 : avant(a, b) ? -1 : 1));
  const triee = map => new Map(trier(map.keys()).map(k => [k, map.get(k)]));

  // La règle. Rend, pour l’instance : config (clé → { valeur, source, remplace }) et devices (nom → { cles, source,
  // remplace }), triés comme dans la sortie d’Incus. `remplace` liste ce que la couche gagnante a recouvert,
  // de la plus récente à la plus ancienne.
  function etendre(e, nom) {
    const inst = e.instances[nom];
    const couches = [...inst.profils.map(p => ({ source: P(p), ent: e.profils[p] })), { source: I(nom), ent: inst }];
    const config = new Map(), devices = new Map();
    for (const { source, ent } of couches) {
      for (const [k, valeur] of lireConfig(ent)) {
        const a = config.get(k);
        config.set(k, { valeur, source, remplace: a ? [{ valeur: a.valeur, source: a.source }, ...a.remplace] : [] });
      }
      for (const [n, cles] of lireDevices(ent)) {
        const a = devices.get(n);
        devices.set(n, { cles, source, remplace: a ? [{ cles: a.cles, source: a.source }, ...a.remplace] : [] });
      }
    }
    return { profils: [...inst.profils], config: triee(config), devices: triee(devices) };
  }
  // Les clés que le périphérique gagnant n’a pas reprises de celui qu’il remplace.
  const perdues = d => (d.remplace.length ? Object.entries(d.remplace[0].cles).filter(([k]) => !(k in d.cles)) : []);
  const estRacine = cles => cles.type === "disk" && cles.path === "/" && !cles.source;   // IsRootDiskDevice

  // Ce qu’Incus contrôlerait et que le simulateur ne contrôle pas : dit d’après le résultat, une fois pour toutes les instances.
  function limites(e) {
    const sortie = new Set(), sans = [], plusieurs = [];
    for (const nom of Object.keys(e.instances)) {
      const ext = etendre(e, nom), racines = [...ext.devices.values()].filter(d => estRacine(d.cles)).length;
      if (racines !== 1) (racines ? plusieurs : sans).push(nom);
      for (const [n, d] of ext.devices) {
        const p = perdues(d).map(([k]) => k), autres = Object.keys(d.cles).filter(k => k !== "type");
        if (d.cles.type === "none" && autres.length) sortie.add(`Limitation du simulateur : il ne valide pas les clés d’un périphérique. Le type none n’en accepte aucune ; ${n}, ${du(d.source)}, porte ${enumerer(autres)}.`);
        // Un disque qui a perdu path n’est plus le disque racine : la limitation suivante le dit, plus précisément.
        else if (d.cles.type !== "none" && p.length && !(racines === 0 && d.cles.type === "disk" && p.includes("path")))
          sortie.add(`Limitation du simulateur : il ne sait pas si ${n}, ${du(d.source)}, reste valide sans ${enumerer(p)} ; Incus refuse un périphérique incomplet.`);
      }
    }
    const suite = "(périphérique disk dont path vaut /) ; Incus signalerait une erreur, le simulateur montre quand même ce que donne la règle.";
    if (sans.length) sortie.add(`Limitation du simulateur : ${enumerer(sans)} ${sans.length > 1 ? "n’ont" : "n’a"} plus de disque racine ${suite}`);
    if (plusieurs.length) sortie.add(`Limitation du simulateur : ${enumerer(plusieurs)} ${plusieurs.length > 1 ? "ont" : "a"} plusieurs disques racine ${suite}`);
    return [...sortie];
  }

  // ---------- Les commandes incus équivalentes ----------
  const citer = mot => (/^[\w@%+=:,.\/-]+$/.test(mot) ? mot : `'${mot.replaceAll("'", "'\\''")}'`);
  const enCommande = argv => "incus " + argv.map(citer).join(" ");
  // Ce qui sépare deux lectures d’une même couche, en commandes.
  function commandesConfig(cible, a, b) {
    const base = cible.genre === "profil" ? "profile" : "config", sortie = [];
    for (const k of a.keys()) if (!b.has(k)) sortie.push([base, "unset", cible.nom, k]);
    const posees = [...b].filter(([k, v]) => a.get(k) !== v).map(([k, v]) => `${k}=${v}`);
    if (posees.length) sortie.push([base, "set", cible.nom, ...posees]);
    return sortie;
  }
  function commandesDevices(cible, a, b) {
    const base = [cible.genre === "profil" ? "profile" : "config", "device"], sortie = [];
    const paires = cles => Object.entries(cles).filter(([k]) => k !== "type").map(([k, v]) => `${k}=${v}`);
    for (const [n, da] of a) if (b.get(n)?.type !== da.type) sortie.push([...base, "remove", cible.nom, n]);
    for (const [n, db] of b) {
      const da = a.get(n);
      if (da?.type !== db.type) { sortie.push([...base, "add", cible.nom, n, db.type, ...paires(db)]); continue; }
      for (const k of Object.keys(da)) if (!(k in db)) sortie.push([...base, "unset", cible.nom, n, k]);
      const posees = Object.entries(db).filter(([k, v]) => da[k] !== v).map(([k, v]) => `${k}=${v}`);
      if (posees.length) sortie.push([...base, "set", cible.nom, n, ...posees]);
    }
    return sortie;
  }

  // ---------- Les manipulations ----------
  // Chacune agit sur une copie de l’état et rend { commandes }, ou { echec, tentative } quand elle est refusée.
  const ligneDe = (ent, sorte, id) => ent[sorte].find(l => l.id === id);
  // Valide la saisie d’une ligne de configuration.
  function poserCle(e, cible, id, texte) {
    const ent = entite(e, cible), ligne = ligneDe(ent, "config", id);
    if (!ligne) return {};
    const a = lireConfig(ent);
    let lu = texte.trim() ? lireCle(texte) : { cle: null };
    // Un seul mot, sans « = », après le nom d’une instance : `incus config set` y lit un réglage du serveur (cmdConfigSet.Run).
    if (lu.echec?.genre === "erreur" && cible.genre === "instance" && texte.trim().split(/\s+/).length === 1)
      lu = { echec: { genre: "limite", message: `sans « = », Incus lit « incus config set ${cible.nom} ${texte.trim()} » comme un réglage du serveur, de clé ${cible.nom} ; ce cas n’est pas simulé` } };
    if (lu.echec) {
      Object.assign(ligne, { b: texte, e: lu.echec });
      return { echec: lu.echec, tentative: [cible.genre === "profil" ? "profile" : "config", "set", cible.nom, ...texte.trim().split(/\s+/)] };
    }
    delete ligne.b; delete ligne.e;
    // Une clé déjà écrite sur une autre ligne y reçoit la valeur ; une valeur vide supprime la clé.
    const autre = ent.config.find(l => l !== ligne && l.t && lireCle(l.t).cle === lu.cle);
    if (lu.cle === null || lu.valeur === "") ent.config = ent.config.filter(l => l !== ligne && l !== autre);
    else { (autre ?? ligne).t = `${lu.cle}=${lu.valeur}`; if (autre) ent.config = ent.config.filter(l => l !== ligne); }
    return { commandes: commandesConfig(cible, a, lireConfig(ent)) };
  }
  // Valide la saisie d’une ligne de périphérique.
  function poserPeripherique(e, cible, id, texte) {
    const ent = entite(e, cible), ligne = ligneDe(ent, "devices", id);
    if (!ligne) return {};
    const a = lireDevices(ent), base = [cible.genre === "profil" ? "profile" : "config", "device"];
    if (!texte.trim()) { ent.devices = ent.devices.filter(l => l !== ligne); return { commandes: commandesDevices(cible, a, lireDevices(ent)) }; }
    const lu = lirePeripherique(texte), mots = texte.trim().split(/\s+/), ancien = ligne.t ? lirePeripherique(ligne.t) : null;
    const refus = echec => { Object.assign(ligne, { b: texte, e: echec }); return { echec, tentative: echec.genre === "erreur" ? echec.tentative : null }; };
    // La même erreur de saisie ne reçoit pas le même message de `device set` (périphérique gardé) et de `device add`.
    const garde = ancien && ancien.nom === mots[0] && ancien.cles.type === mots[1];
    // Deux mots dont le premier est sans « = » : `device set` y lit la forme ancienne, « clé valeur » (getConfig).
    if (lu.echec?.mot !== undefined && garde && mots.length === 4 && !mots[2].includes("="))
      return refus({ genre: "limite", message: "la forme ancienne « incus config device set <instance> <périphérique> <clé> <valeur> » n’est pas simulée" });
    if (lu.echec?.mot !== undefined) return refus(garde
      ? { genre: "erreur", message: `Error: Invalid key=value configuration: ${lu.echec.mot}`, tentative: [...base, "set", cible.nom, ...mots.filter((m, i) => i !== 1)] }
      : { genre: "erreur", message: `Error: No value found in "${lu.echec.mot}"`, tentative: [...base, "add", cible.nom, ...mots] });
    if (lu.echec) return refus({ ...lu.echec, tentative: [...base, "add", cible.nom, ...mots] });
    if (ent.devices.some(l => l !== ligne && l.t && lirePeripherique(l.t).nom === lu.nom))
      return refus({ genre: "erreur", message: "Error: The device already exists", tentative: [...base, "add", cible.nom, ...mots] });
    delete ligne.b; delete ligne.e;
    ligne.t = ecrirePeripherique(lu.nom, lu.cles);
    return { commandes: commandesDevices(cible, a, lireDevices(ent)) };
  }
  const poser = { config: poserCle, devices: poserPeripherique };
  // Abandonne une saisie refusée : la ligne retrouve son texte appliqué (une ligne neuve disparaît).
  function abandonner(e, cible, sorte, id) {
    const ent = entite(e, cible), ligne = ligneDe(ent, sorte, id);
    if (ligne) { delete ligne.b; delete ligne.e; if (!ligne.t) ent[sorte] = ent[sorte].filter(l => l !== ligne); }
    return {};
  }
  const nouvelleLigne = (e, cible, sorte) => { entite(e, cible)[sorte].push({ id: ++e.suivant, t: "" }); return { focus: "l" + e.suivant }; };
  const oter = (e, cible, sorte, id) => poser[sorte](e, cible, id, "");
  // Les formes dont les recettes se servent : par nom de clé ou de périphérique plutôt que par ligne.
  function ligneNommee(e, cible, sorte, nom) {
    const ent = entite(e, cible), lire = sorte === "config" ? l => lireCle(l.t).cle : l => lirePeripherique(l.t).nom;
    return ent[sorte].find(l => l.t && lire(l) === nom) ?? ent[sorte][ent[sorte].push({ id: ++e.suivant, t: "" }) - 1];
  }
  const definir = (cible, cle, valeur) => e => poserCle(e, cible, ligneNommee(e, cible, "config", cle).id, `${cle}=${valeur}`);
  const peripherique = (cible, texte) => e => poserPeripherique(e, cible, ligneNommee(e, cible, "devices", texte.split(" ")[0]).id, texte);

  // La liste des profils d’une instance.
  const ajouterProfil = (n, p) => e => { e.instances[n].profils.push(p); return { commandes: [["profile", "add", n, p]] }; };
  const retirerProfil = (n, p) => e => { e.instances[n].profils = e.instances[n].profils.filter(x => x !== p); return { commandes: [["profile", "remove", n, p]] }; };
  // Incus n’a pas de commande pour déplacer un profil : `profile assign` redonne toute la liste.
  const deplacerProfil = (n, p, pas) => e => {
    const liste = e.instances[n].profils, i = liste.indexOf(p), j = i + pas;
    if (i < 0 || j < 0 || j >= liste.length) return {};
    [liste[i], liste[j]] = [liste[j], liste[i]];
    return { commandes: [["profile", "assign", n, liste.join(",")]] };
  };
  // Un périphérique que l’instance tient d’un profil : le copier chez elle (override), le remplacer par un
  // périphérique de type none, ou tenter de le retirer (refusé).
  const surcharger = (n, nom) => e => {
    const inst = e.instances[n], d = etendre(e, n).devices.get(nom), argv = ["config", "device", "override", n, nom];
    if (lireDevices(inst).has(nom)) return { tentative: argv, echec: { genre: "erreur", message: "Error: The device already exists" } };
    if (!d) return { tentative: argv, echec: { genre: "erreur", message: "Error: The profile device doesn't exist" } };
    inst.devices.push({ id: ++e.suivant, t: ecrirePeripherique(nom, d.cles) });
    return { commandes: [argv] };
  };
  const masquer = (n, nom) => e => {
    const inst = e.instances[n], argv = ["config", "device", "add", n, nom, "none"];
    if (lireDevices(inst).has(nom)) return { tentative: argv, echec: { genre: "erreur", message: "Error: The device already exists" } };
    inst.devices.push({ id: ++e.suivant, t: `${nom} none` });
    return { commandes: [argv] };
  };
  const retirerHerite = (n, nom) => e => {
    const d = etendre(e, n).devices.get(nom), argv = ["config", "device", "remove", n, nom];
    if (!d) return { tentative: argv, echec: { genre: "erreur", message: "Error: Device doesn't exist" } };
    if (d.source.genre === "instance") return oter(e, I(n), "devices", e.instances[n].devices.find(l => l.t && lirePeripherique(l.t).nom === nom).id);
    return { tentative: argv, pourquoi: `${nom} n’est pas un périphérique de l’instance ${n} : elle le tient ${du(d.source)}.`,
      echec: { genre: "erreur", message: "Error: Device from profile(s) cannot be removed from individual instance. Override device or modify profile instead" } };
  };
  const montrer = n => e => { e.courante = n; return { phrases: decrire(e, n) }; };

  // ---------- Explications : calculées à partir de ce qui vient de se passer ----------
  const enumerer = l => (l.length > 1 ? l.slice(0, -1).join(", ") + " et " + l.at(-1) : l[0] ?? "");
  const nomDe = s => (s.genre === "instance" ? `l’instance ${s.nom}` : `le profil ${s.nom}`);
  const du = s => (s.genre === "instance" ? `de l’instance ${s.nom}` : `du profil ${s.nom}`);
  const court = s => (s.genre === "instance" ? "instance" : `profil ${s.nom}`);
  const resume = cles => [cles.type, ...Object.entries(cles).filter(([k]) => k !== "type").map(([k, v]) => `${k}=${v}`)].join(" ");
  // Pourquoi la couche gagnante passe devant l’autre.
  const raison = (gagnante, autre) => (gagnante.genre === "instance" ? "l’instance passe après ses profils"
    : `${gagnante.nom} vient après ${autre.nom} dans la liste`);
  const pareil = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  // Dans ce qu’une couche gagnante recouvre, la première définition qui a changé : celle que la manipulation a touchée.
  const touchee = (a, b) => b.remplace.find(r => !a.remplace.some(x => pareil(x, r)));
  // Dans un paragraphe qui porte déjà le nom de l’instance, « de l’instance » suffit.
  const de = s => (s.genre === "instance" ? "de l’instance" : `du profil ${s.nom}`);
  const seul = s => (s.genre === "instance" ? "L’instance est seule" : `Le profil ${s.nom} est seul`);

  function expliquerCle(k, a, b) {
    if (!b) return `${k} disparaît : plus aucune couche ne la définit.`;
    if (!a) return `${k} apparaît : ${b.valeur}, valeur ${de(b.source)}.`;
    const r = b.remplace[0];
    if (a.valeur === b.valeur && meme(a.source, b.source)) {
      const t = touchee(a, b);
      return t ? `${k} reste à ${b.valeur}, valeur ${de(b.source)} : ${nomDe(t.source)} dit ${t.valeur}, mais ${raison(b.source, t.source)}.` : null;
    }
    // La valeur d’avant n’est rappelée que si ce n’est pas celle que la nouvelle remplace.
    const avant = r && r.valeur === a.valeur && meme(r.source, a.source) ? "" : ` (avant : ${a.valeur}${meme(a.source, b.source) ? "" : ", " + de(a.source)})`;
    return `${k} vaut ${b.valeur}, valeur ${de(b.source)}${avant}`
      + (r ? ` ; elle remplace celle ${de(r.source)} (${r.valeur}), car ${raison(b.source, r.source)}.`
        : meme(a.source, b.source) ? "." : `. ${seul(b.source)} à la définir.`);
  }
  function expliquerPeripherique(n, a, b) {
    if (!b) return `Le périphérique ${n} disparaît : plus aucune couche ne le définit.`;
    if (!a) return `Le périphérique ${n} apparaît (${resume(b.cles)}), ${de(b.source)}.`;
    const r = b.remplace[0], p = perdues(b);
    if (pareil(a.cles, b.cles) && meme(a.source, b.source)) {
      const t = touchee(a, b);
      return t ? `${n} reste le périphérique ${de(b.source)} : celui ${de(t.source)} vaut maintenant ${resume(t.cles)}, mais ${raison(b.source, t.source)}.` : null;
    }
    return `${n} est le périphérique ${de(b.source)} (${resume(b.cles)})`
      + (r ? ` ; il remplace en entier celui ${de(r.source)}, ${p.length ? `sans en reprendre ${enumerer(p.map(([k, v]) => `${k}=${v}`))}` : "sans perdre de clé"}, car ${raison(b.source, r.source)}.` : ".")
      + (b.cles.type === "none" ? " De type none, il ne crée rien dans l’instance." : "");
  }
  // Ce qu’une manipulation a changé à la configuration étendue de chaque instance, en phrases.
  // Deux instances à qui il arrive la même chose partagent leur paragraphe.
  function expliquer(a, b) {
    const dits = new Map(), noms = [b.courante, ...Object.keys(b.instances).filter(n => n !== b.courante)];
    for (const n of noms) {
      const A = etendre(a, n), B = etendre(b, n), p = [];
      const liste = pareil(A.profils, B.profils) ? "" : B.profils.length ? `Les profils sont maintenant ${enumerer(B.profils)}, dans cet ordre. ` : "Plus aucun profil. ";
      for (const k of trier(new Set([...A.config.keys(), ...B.config.keys()]))) p.push(expliquerCle(k, A.config.get(k), B.config.get(k)));
      for (const k of trier(new Set([...A.devices.keys(), ...B.devices.keys()]))) p.push(expliquerPeripherique(k, A.devices.get(k), B.devices.get(k)));
      const dites = p.filter(Boolean);
      const texte = dites.length ? liste + dites.join(" ") : pareil(couchesDe(a, n), couchesDe(b, n)) ? null : liste + "La configuration étendue ne change pas.";
      if (texte) dits.set(texte, [...(dits.get(texte) ?? []), n]);
    }
    const deja = limites(a);
    const phrases = [...[...dits].map(([texte, qui]) => `${enumerer(qui)} — ${texte}`), ...limites(b).filter(l => !deja.includes(l))];
    return phrases.length ? phrases : ["Aucune configuration étendue ne change."];
  }
  const couchesDe = (e, n) => [e.instances[n].profils.map(p => [p, [...lireConfig(e.profils[p])], [...lireDevices(e.profils[p])]]),
    [...lireConfig(e.instances[n])], [...lireDevices(e.instances[n])]];
  // La configuration étendue d’une instance, en phrases : d’où vient chaque clé, chaque périphérique.
  function decrire(e, n) {
    const ext = etendre(e, n);
    return [
      `${n} a ${ext.profils.length ? `${ext.profils.length > 1 ? "les profils" : "le profil"} ${enumerer(ext.profils)}${ext.profils.length > 1 ? ", dans cet ordre" : ""}` : "aucun profil"}.`,
      ext.config.size ? `Clés : ${[...ext.config].map(([k, c]) => `${k}=${c.valeur} (${court(c.source)})`).join(", ")}.` : "Aucune clé de configuration.",
      ext.devices.size ? `Périphériques : ${[...ext.devices].map(([k, d]) => `${k} (${court(d.source)})`).join(", ")}.` : "Aucun périphérique.",
    ];
  }

  // Une phrase d’explication, en paragraphe : le nom de l’instance qu’elle concerne ressort, une limitation se signale.
  function paragraphe(phrase) {
    const [, nom, reste] = phrase.match(/^(.+?) — (.*)$/s) ?? [];
    return el("p", { class: phrase.startsWith("Limitation") ? "limite" : phrase.startsWith("Incus refuse") ? "erreur" : false },
      ...(nom ? [el("strong", {}, nom), " — " + reste] : [phrase]));
  }
  // Termine une manipulation faite sur la copie `b` de l’état `a` : journal, explication, ce qui doit clignoter.
  function conclure(a, b, r) {
    for (const argv of r.commandes ?? []) b.journal.push({ n: ++b.commandes, argv });
    if (r.echec?.genre === "erreur" && r.tentative) b.journal.push({ n: ++b.commandes, argv: r.tentative, erreur: r.echec.message });
    b.journal = b.journal.slice(-JOURNAL_MAX);
    const phrases = r.phrases ?? (r.echec?.genre === "erreur" ? [`Incus refuse la commande : « ${r.echec.message} ».`, r.pourquoi ?? "Rien n’est modifié : la ligne refusée reste à corriger."]
      : r.echec ? [`Limitation du simulateur : ${r.echec.message}.`, "Rien n’est modifié."]
      : r.commandes?.length ? expliquer(a, b) : null);
    if (phrases) b.bilan = phrases;
    // Clignotent : les lignes dont le texte est nouveau, et les entrées de la configuration étendue qui ont changé.
    const signaux = new Set();
    for (const genre of ["profils", "instances"]) for (const [nom, ent] of Object.entries(b[genre])) for (const sorte of ["config", "devices"]) {
      const textes = new Set(a[genre][nom][sorte].map(l => l.t));
      for (const l of ent[sorte]) if (l.t && !textes.has(l.t)) signaux.add("l" + l.id);
    }
    if (a.courante === b.courante) {
      const A = etendre(a, a.courante), B = etendre(b, b.courante);
      for (const sorte of ["config", "devices"]) for (const [k, v] of B[sorte]) {
        const x = A[sorte].get(k);
        if (!x || !pareil([x.valeur, x.cles, x.source], [v.valeur, v.cles, v.source])) signaux.add(sorte + ":" + k);
      }
    }
    return { phrases, signaux, focus: r.focus };
  }
  // Une manipulation du lecteur : appliquée aussitôt.
  function agir(manip) {
    const a = etat, b = structuredClone(etat), fin = conclure(a, b, manip(b) ?? {});
    etat = b;
    if (recette && fin.phrases) recette.libre = fin.phrases;   // à la fin d’une recette, le lecteur a repris la main
    dessiner(fin.signaux, fin.focus);
    if (recette) majRecettes();
  }

  // ---------- Recettes : les manipulations des expériences, jouées pas à pas ----------
  // Une étape prépare la manipulation, tape sa commande dans le journal, puis l’applique et rend son explication.
  const etape = manip => async annulee => {
    const a = etat, b = structuredClone(etat), fin = conclure(a, b, manip(b) ?? {});
    if (!await frapper(b.journal.slice(a.journal.length), annulee)) return null;
    etat = b;
    return fin;
  };
  // Tape les commandes dans le journal, caractère par caractère. Une recette en pause gèle la frappe.
  function frapper(entrees, annulee) {
    const texte = entrees.map(c => enCommande(c.argv)).join("\n"), duree = Math.max(ATTENTE_MIN, texte.length * FRAPPE);
    const journal = racine.querySelector(".journal"), ligne = el("li", { class: "frappe" }, el("span", { class: "invite" }, "$ "), el("span", {}));
    if (texte) { journal.querySelector(".vide")?.remove(); journal.append(ligne); journal.scrollTop = journal.scrollHeight; }
    let ecoule = 0, avant = performance.now();
    return new Promise(fini => {
      const tic = () => {
        if (annulee()) return fini(false);
        const maintenant = performance.now();
        if (!recette?.gel) ecoule += maintenant - avant;
        avant = maintenant;
        ligne.lastChild.textContent = texte.slice(0, Math.round(texte.length * Math.min(1, ecoule / (duree - 250)))).replaceAll("\n", "\n$ ");
        if (ecoule >= duree) return fini(true);
        setTimeout(tic, 40);
      };
      tic();
    });
  }
  // Les titres disent l’action que la recette va faire, pas son résultat : celui-ci est expliqué après coup.
  const RECETTES = {
    "cles": { instance: "v2", etapes: [
      ["Ajouter le profil petit à v2, en fin de liste.", etape(ajouterProfil("v2", "petit"))],
      ["Monter petit avant moyen.", etape(deplacerProfil("v2", "petit", -1))],
      ["Retirer limits.cpu de l’instance v2.", etape(definir(I("v2"), "limits.cpu", ""))],
    ] },
    "profil-partage": { instance: "v2", etapes: [
      ["Dans le profil moyen, passer limits.memory à 4GiB.", etape(definir(P("moyen"), "limits.memory", "4GiB"))],
      ["Dans le profil moyen, passer limits.cpu à 8.", etape(definir(P("moyen"), "limits.cpu", "8"))],
      ["Afficher l’autre instance, v3.", etape(montrer("v3"))],
    ] },
    "peripherique-entier": { instance: "v2", etapes: [
      ["Dans le profil moyen, réduire root à size=20GiB.", etape(peripherique(P("moyen"), "root disk size=20GiB"))],
      ["Lui rendre path=/ et pool=default.", etape(peripherique(P("moyen"), "root disk size=20GiB path=/ pool=default"))],
      ["Donner à v2 un root réduit à size=30GiB.", etape(peripherique(I("v2"), "root disk size=30GiB"))],
    ] },
    "override": { instance: "v2", etapes: [
      ["Surcharger root dans v2 : bouton « override ».", etape(surcharger("v2", "root"))],
      ["Dans la copie, passer size à 30GiB.", etape(peripherique(I("v2"), "root disk path=/ pool=default size=30GiB"))],
      ["Dans le profil moyen, passer size à 40GiB.", etape(peripherique(P("moyen"), "root disk path=/ pool=default size=40GiB"))],
    ] },
    "none": { instance: "v3", etapes: [
      ["Essayer de retirer eth0 de v3.", etape(retirerHerite("v3", "eth0"))],
      ["Ajouter à v3 un eth0 de type none : bouton « none ».", etape(masquer("v3", "eth0"))],
      ["Afficher l’autre instance, v2.", etape(montrer("v2"))],
    ] },
  };
  const etapesDe = r => RECETTES[r.nom].etapes;
  const finie = r => r.pas >= etapesDe(r).length && !r.occupe;

  // Abandonne l’étape en cours d’exécution et revient à l’état qui la précédait.
  function annuler(r) {
    r.jeton++; r.occupe = false; r.gel = false;
    etat = structuredClone(r.etats[r.pas]);
    dessiner();
  }
  function ouvrir(nom) {
    if (recette) fermer();
    etat = depart(); etat.courante = RECETTES[nom].instance;
    recette = { nom, pas: 0, etats: [structuredClone(etat)], explications: [decrire(etat, etat.courante).map((p, i) => (i ? p : "Départ. " + p))],
      occupe: false, gel: false, lecture: continu, libre: null, jeton: 0, enBoucle: false };
    dessiner(); majRecettes();
    continu ? defiler(recette) : executer(recette);
  }
  // Ferme la recette en laissant la simulation dans l’état où elle est.
  function fermer() {
    if (recette.occupe) annuler(recette);
    recette = null;
    dessiner(); majRecettes();
  }
  // Exécute l’étape suivante, puis mémorise l’état obtenu et son explication.
  async function executer(r) {
    const i = r.pas, jeton = ++r.jeton;
    r.occupe = true; r.libre = null;
    dessiner(); majRecettes();
    const fin = await etapesDe(r)[i][1](() => recette !== r || r.jeton !== jeton);
    if (!fin || recette !== r || r.jeton !== jeton) return;   // étape annulée par un retour en arrière
    r.pas = i + 1; r.etats[r.pas] = structuredClone(etat); r.explications[r.pas] = fin.phrases; r.occupe = false; r.gel = false;
    dessiner(fin.signaux); majRecettes();
  }
  // Enchaînement sans pause : une étape, le temps de lire, la suivante… tant que la lecture n’est pas suspendue.
  async function defiler(r) {
    const dormir = ms => new Promise(fini => setTimeout(fini, ms));
    r.enBoucle = true;
    while (recette === r && r.lecture) {
      if (r.occupe) { await dormir(80); continue; }   // une étape lancée à la main se termine d’abord
      if (r.pas >= etapesDe(r).length) { r.lecture = false; break; }
      if (r.pas > 0) for (let reste = PAUSE; reste > 0 && recette === r && r.lecture; reste -= 60) await dormir(60);
      if (recette !== r || !r.lecture || r.occupe) continue;
      await executer(r);
    }
    r.enBoucle = false;
    if (recette === r) { dessiner(); majRecettes(); }
  }
  // Le bouton principal : continuer, suspendre ou reprendre, rejouer — selon l’état de la recette.
  function avancerRecette() {
    const r = recette;
    if (r.occupe) { r.gel = !r.gel; r.lecture = continu && !r.gel; }               // pause ou reprise, au milieu de l’étape
    else if (r.pas >= etapesDe(r).length) { r.pas = 0; r.libre = null; etat = structuredClone(r.etats[0]); dessiner(); r.lecture = continu; continu ? defiler(r) : executer(r); }
    else if (continu) { r.lecture = !r.lecture; if (r.lecture && !r.enBoucle) defiler(r); }
    else executer(r);
    majRecettes();
  }
  function reculerRecette() {
    const r = recette;
    r.lecture = false; r.libre = null;
    if (r.occupe) annuler(r);                                                        // revient avant l’étape en cours
    else if (r.pas > 0) { r.pas--; etat = structuredClone(r.etats[r.pas]); dessiner(); }
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
      const nom = carte.dataset.recette, r = recette?.nom === nom ? recette : null, etapes = RECETTES[nom].etapes, n = etapes.length;
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
      const etatDe = i => i === r.pas ? (r.occupe ? "courante" : "prochaine") : i > r.pas ? ""
        : i === r.pas - 1 && !r.occupe && !r.libre ? "faite expliquee" : "faite";
      const explication = r.occupe ? [r.gel ? "En pause, au milieu de l’étape." : "En cours…"] : r.libre ?? r.explications[r.pas];
      const principal = r.occupe ? (r.gel ? "▶ Reprendre" : "❚❚ Pause") : fin ? "↻ Rejouer"
        : continu && r.lecture ? "❚❚ Pause" : r.pas === 0 ? "Commencer ▶" : "Continuer ▶";
      bloc.replaceChildren(
        el("div", { class: "recette-entete" }, el("span", { class: "recette-titre" }, "Recette"), el("span", { class: "recette-rang" }, action),
          bouton("✕", fermer, { class: "fermer", "aria-label": "Fermer la recette", title: "Fermer la recette" })),
        el("ol", { class: "recette-etapes" }, ...etapes.map(([titre], i) =>
          el("li", { class: etatDe(i), "aria-current": i === (r.occupe ? r.pas : r.pas - 1) ? "step" : false }, titre))),
        el("div", { class: "explication", role: "status", "aria-live": "polite" },
          el("p", { class: "explication-titre" }, r.occupe ? "Ce qui se passe" : r.libre ? "Votre manipulation" : "Ce qui vient de se passer"),
          ...explication.map(paragraphe)),
        el("div", { class: "lecteur" },
          bouton("◀ Revenir", reculerRecette, { "aria-label": "Revenir à l’étape précédente", disabled: (r.pas === 0 && !r.occupe) && "" }),
          bouton(principal, avancerRecette, { class: "jouer" }), sansPause));
    }
  }
  // Changer d’expérience ferme la recette ouverte : sa carte ne serait plus visible.
  new MutationObserver(() => { if (recette && cartes.find(c => c.dataset.recette === recette.nom)?.hidden) fermer(); })
    .observe(document.querySelector(".experiences") ?? document.body, { subtree: true, attributes: true, attributeFilter: ["hidden"] });

  // ---------- Interface ----------
  const el = (balise, attributs = {}, ...enfants) => {
    const e = document.createElement(balise);
    for (const [k, v] of Object.entries(attributs)) {
      if (k.startsWith("on")) e.addEventListener(k.slice(2), v); else if (v !== false && v != null) e.setAttribute(k, v);
    }
    e.append(...enfants);
    return e;
  };
  // Un bouton ne prend pas le champ des mains du lecteur : la saisie en cours est validée, puis il agit.
  const bouton = (texte, action, attributs = {}) => el("button", { type: "button", onmousedown: ev => ev.preventDefault(),
    onclick: () => { deposer(); action(); }, ...attributs }, texte);
  function deposer() {
    const champ = document.activeElement;
    if (champ?.valider && champ.value !== champ.defaultValue) champ.valider();
  }

  // Un champ de saisie prend la hauteur de son texte : une longue ligne de périphérique passe à la ligne, comme dans un terminal.
  const ajuster = champ => { champ.style.height = "auto"; champ.style.height = champ.scrollHeight + 2 + "px"; };

  // Une chaîne comme yaml.v2 l’écrit : entre guillemets doubles si, nue, elle se lirait comme un nombre, un booléen,
  // une date ou rien ; entre apostrophes si elle ne peut pas s’écrire nue.
  function scalaire(s) {
    const nu = s.replaceAll("_", "");
    if (s === "" || /^(y|Y|yes|Yes|YES|n|N|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF|~|null|Null|NULL|\.nan|\.NaN|\.NAN|[-+]?\.(inf|Inf|INF))$/.test(s)
      || /^[-+]?(0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|[0-9]+)$/.test(nu) || /^[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$/.test(nu)
      || /^\d{4}-\d\d?-\d\d?([Tt ]\d\d?:\d\d?:\d\d?(\.\d+)?(Z|[-+]\d\d?(:\d\d)?)?)?$/.test(s) || /^[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+(\.[0-9_]*)?$/.test(s))
      return JSON.stringify(s);
    if (/^[#,\[\]{}&*!|>'"%@`]|^[-?:](\s|$)|^(---|\.\.\.)|:(\s|$)|\s#|^\s|\s$/.test(s)) return `'${s.replaceAll("'", "''")}'`;
    return s;
  }
  // La sortie de `incus config show <instance> --expanded`, ligne à ligne ; chaque ligne sait d’où elle vient.
  function sortie(ext) {
    // Une vraie instance porte aussi des clés volatile.* et image.*, qu’Incus tient lui-même : elles ne sont pas simulées.
    const lignes = [{ y: ext.config.size ? "config:" : "config: {}" }, { note: "  # + clés volatile.*, image.*", hors: true }];
    for (const [k, c] of ext.config) {
      lignes.push({ y: `  ${scalaire(k)}: ${scalaire(c.valeur)}`, source: c.source, signal: "config:" + k });
      c.remplace.forEach((r, i) => lignes.push({ note: `${i ? "et" : "remplace"} ${r.valeur}, ${du(r.source)}` }));
    }
    lignes.push({ y: ext.devices.size ? "devices:" : "devices: {}" });
    for (const [n, d] of ext.devices) {
      const p = perdues(d);
      lignes.push({ y: `  ${scalaire(n)}:`, source: d.source, signal: "devices:" + n });
      d.remplace.forEach((r, i) => lignes.push({ note: `${i ? "qui remplaçait" : "remplace en entier"} celui ${du(r.source)}` }));
      for (const k of trier(Object.keys(d.cles))) lignes.push({ y: `    ${scalaire(k)}: ${scalaire(d.cles[k])}`, groupe: d.source, signal: "devices:" + n });
      for (const [k, v] of p) lignes.push({ perdue: `    ${scalaire(k)}: ${scalaire(v)}` });
    }
    lignes.push({ y: ext.profils.length ? "profiles:" : "profiles: []" }, ...ext.profils.map(p => ({ y: `- ${scalaire(p)}` })));
    return lignes;
  }
  // Le modèle, lisible par verifier-incus.js : ce que chaque couche contient, et la configuration étendue de chaque instance.
  const objet = map => Object.fromEntries(map);
  const modele = () => ({
    courante: etat.courante,
    profils: Object.fromEntries(Object.entries(etat.profils).map(([n, p]) => [n, { config: objet(lireConfig(p)), devices: objet(lireDevices(p)) }])),
    instances: Object.fromEntries(Object.entries(etat.instances).map(([n, i]) => {
      const ext = etendre(etat, n);
      return [n, { profils: i.profils, config: objet(lireConfig(i)), devices: objet(lireDevices(i)),
        etendue: { config: objet(new Map([...ext.config].map(([k, c]) => [k, c.valeur]))), devices: objet(new Map([...ext.devices].map(([k, d]) => [k, d.cles]))) } }];
    })),
  });

  function dessiner(signaux = new Set(), focus = null) {
    generation++;
    // Pendant une recette en cours, le lecteur regarde ; une recette terminée lui rend la main.
    const fige = !!recette && !finie(recette), g = generation;
    const n = etat.courante, inst = etat.instances[n], ext = etendre(etat, n);
    const actif = racine.contains(document.activeElement) ? document.activeElement : null;
    const garde = actif && { id: actif.dataset.id, debut: actif.selectionStart, fin: actif.selectionEnd };

    // Une couche se modifie ligne à ligne : ses clés, puis ses périphériques. Une ligne que la configuration
    // étendue ne retient pas est barrée et le dit ; une saisie refusée garde son refus sous elle.
    const editeur = cible => {
      const ent = entite(etat, cible), a = cible.genre === "profil" ? "au profil" : "à l’instance";
      const rangee = (sorte, ligne, i) => {
        const quoi = sorte === "config" ? "Clé" : "Périphérique";
        const texte = ligne.b ?? ligne.t, lu = !ligne.t ? null : sorte === "config" ? lireCle(ligne.t).cle : lirePeripherique(ligne.t).nom;
        const gagnante = lu === null ? null : ext[sorte].get(lu).source, recouverte = gagnante && !meme(gagnante, cible);
        const champ = el("textarea", { rows: "1", spellcheck: "false", autocomplete: "off", disabled: fige && "", "data-id": "l" + ligne.id,
          placeholder: sorte === "config" ? "clé=valeur" : "nom type clé=valeur…", "aria-label": `${quoi} ${i + 1} ${du(cible)}`,
          "aria-invalid": ligne.e ? "true" : false, class: signaux.has("l" + ligne.id) ? "signale" : false,
          onkeydown: ev => {
            if (ev.key === "Enter") { ev.preventDefault(); champ.valider(); }
            if (ev.key === "Escape") agir(e => abandonner(e, cible, sorte, ligne.id));
          },
          oninput: () => ajuster(champ),
          onchange: () => setTimeout(() => champ.valider(), 0) }, texte);   // après le déplacement du curseur : le dessin le suit
        champ.valider = () => { if (g === generation && (champ.value !== texte || !ligne.t)) agir(e => poser[sorte](e, cible, ligne.id, champ.value)); };
        return el("li", { class: ligne.e ? "refusee" : recouverte ? "recouverte" : false },
          champ,
          recouverte && !ligne.e ? el("span", { class: "sort", title: `${sorte === "config" ? "Remplacée" : "Remplacé en entier"} par ${nomDe(gagnante)}` },
            sorte === "config" ? "remplacée" : "remplacé") : "",
          bouton("✕", () => agir(e => oter(e, cible, sorte, ligne.id)), { disabled: fige && "", "data-id": "oter/" + ligne.id, "aria-label": `Retirer ${lu ?? "la ligne"} ${du(cible)}` }),
          ligne.e ? el("span", { class: "refus" }, ligne.e.genre === "erreur" ? ligne.e.message : "Limitation du simulateur : " + ligne.e.message) : "");
      };
      const plus = (sorte, texte, quoi) => bouton(texte, () => agir(e => nouvelleLigne(e, cible, sorte)),
        { class: "plus", disabled: fige && "", "data-id": `plus/${cible.nom}/${sorte}`, "aria-label": `Ajouter ${quoi} ${a} ${cible.nom}` });
      return [
        el("ul", { class: "lignes" }, ...ent.config.map((l, i) => rangee("config", l, i)), ...ent.devices.map((l, i) => rangee("devices", l, i))),
        el("div", { class: "ajouts" }, el("span", {}, "config"), plus("config", "+ clé", "une clé"), el("span", {}, "devices"), plus("devices", "+ périphérique", "un périphérique")),
      ];
    };

    const autres = Object.keys(etat.profils).filter(p => !inst.profils.includes(p));
    const zoneProfils = el("section", { class: "zone-profils cadre" },
      el("h2", {}, `Profils de ${n}, dans l’ordre`),
      inst.profils.length ? "" : el("p", { class: "vide" }, "Aucun profil."),
      el("ol", { class: "pile" }, ...inst.profils.map((p, i) => {
        const partage = Object.keys(etat.instances).filter(x => x !== n && etat.instances[x].profils.includes(p));
        return el("li", { class: "couche profil" },
          el("div", { class: "couche-entete" }, el("span", { class: "rang" }, String(i + 1)), el("code", { class: "nom" }, p),
            el("span", { class: "partage", title: partage.length ? `Ce profil sert aussi à ${enumerer(partage)}` : false }, partage.length ? `aussi : ${partage.join(", ")}` : ""),
            bouton("↑", () => agir(deplacerProfil(n, p, -1)), { disabled: (fige || i === 0) && "", "data-id": "monter/" + p, "aria-label": `Monter le profil ${p}` }),
            bouton("↓", () => agir(deplacerProfil(n, p, 1)), { disabled: (fige || i === inst.profils.length - 1) && "", "data-id": "descendre/" + p, "aria-label": `Descendre le profil ${p}` }),
            bouton("retirer", () => agir(retirerProfil(n, p)), { disabled: fige && "", "data-id": "retirer/" + p, "aria-label": `Retirer le profil ${p} de ${n}`, title: enCommande(["profile", "remove", n, p]) })),
          ...editeur(P(p)));
      })),
      autres.length ? el("ul", { class: "autres" }, ...autres.map(p => el("li", {},
        el("code", { class: "nom" }, p), el("span", { class: "contenu" }, [...etat.profils[p].config, ...etat.profils[p].devices].map(l => l.t).filter(Boolean).join(" · ") || "vide"),
        bouton("ajouter", () => agir(ajouterProfil(n, p)), { disabled: fige && "", "data-id": "ajouter/" + p, "aria-label": `Ajouter le profil ${p} à ${n}`, title: enCommande(["profile", "add", n, p]) })))) : "");

    const herites = [...ext.devices].filter(([, d]) => d.source.genre === "profil");
    const zoneInstance = el("section", { class: "zone-instance cadre" },
      el("h2", {}, "Puis l’instance"),
      el("div", { class: "onglets", role: "group", "aria-label": "Instance affichée" }, ...Object.keys(etat.instances).map(x =>
        bouton(x, () => agir(montrer(x)), { "aria-pressed": String(x === n), disabled: fige && "", "data-id": "montrer/" + x }))),
      el("div", { class: "couche instance" },
        el("div", { class: "couche-entete" }, el("span", { class: "rang" }, String(inst.profils.length + 1)), el("code", { class: "nom" }, n), el("span", { class: "partage" }, "sa configuration propre")),
        ...editeur(I(n))),
      herites.length ? el("p", { class: "herites-titre" }, "Périphériques hérités d’un profil") : "",
      el("ul", { class: "herites" }, ...herites.map(([nom, d]) => el("li", {}, el("code", {}, nom), el("span", { class: "origine" }, d.source.nom),
        bouton("override", () => agir(surcharger(n, nom)), { disabled: fige && "", "data-id": "override/" + nom, "aria-label": `Surcharger ${nom} dans ${n}`, title: enCommande(["config", "device", "override", n, nom]) }),
        bouton("none", () => agir(masquer(n, nom)), { disabled: fige && "", "data-id": "none/" + nom, "aria-label": `Remplacer ${nom} par un périphérique none dans ${n}`, title: enCommande(["config", "device", "add", n, nom, "none"]) }),
        bouton("✕", () => agir(retirerHerite(n, nom)), { disabled: fige && "", "data-id": "retirer-herite/" + nom, "aria-label": `Retirer ${nom} de ${n}`, title: enCommande(["config", "device", "remove", n, nom]) })))));

    // Le terminal : les commandes équivalentes aux manipulations, puis la configuration étendue qu’Incus afficherait.
    const origine = s => (s.genre === "instance" ? "← instance" : "← " + s.nom);
    const zoneTerminal = el("section", { class: "zone-terminal" },
      el("h2", {}, "Configuration étendue"),
      el("div", { class: "terminal-incus" },
        el("ol", { class: "journal", "aria-label": "Commandes incus équivalentes aux manipulations" },
          ...(etat.journal.length ? etat.journal.flatMap(c => [el("li", { "data-n": c.n, "data-argv": JSON.stringify(c.argv), "data-erreur": c.erreur ?? false }, el("span", { class: "invite" }, "$ "), enCommande(c.argv)),
            ...(c.erreur ? [el("li", { class: "erreur" }, c.erreur)] : [])]) : [el("li", { class: "vide" }, "# chaque manipulation s’écrit ici en commandes incus")])),
        el("div", { class: "etendue" },
          el("p", { class: "commande" }, el("span", { class: "invite" }, "$ "), enCommande(["config", "show", n, "--expanded"])),
          el("ol", { class: "yaml-lignes" }, ...sortie(ext).map(l => l.hors ? el("li", { class: "hors" }, l.note) : l.note ? el("li", { class: "glose" }, "↳ " + l.note)
            : l.perdue ? el("li", { class: "perdue" }, el("code", {}, l.perdue), el("span", { class: "origine" }, "clé perdue"))
            : el("li", { class: [(l.source ?? l.groupe)?.genre ?? "", l.source ? "entree" : "", signaux.has(l.signal) ? "signale" : ""].join(" ").trim() || false },
              el("code", { class: "yaml" }, l.y), l.source ? el("span", { class: "origine" }, origine(l.source)) : ""))))));

    const alertes = limites(etat);
    const zoneBilan = el("section", { class: "zone-bilan cadre" },
      el("h2", {}, "Ce que la dernière manipulation a changé"),
      bouton("Remettre à zéro", () => { if (recette) fermer(); etat = depart(); dessiner(); }, { class: "zero", "data-id": "zero" }),
      el("div", { class: "bilan", role: "status", "aria-live": "polite" },
        ...(etat.bilan ?? ["Modifiez une ligne et validez par Entrée, ou servez-vous des boutons : l’effet sur la configuration étendue s’explique ici."]).map(paragraphe),
        ...alertes.filter(a => !etat.bilan?.includes(a)).map(paragraphe)),
      el("p", { class: "mention" }, "Limitations du simulateur : il ne valide ni les noms de clés ni leurs valeurs, et ne dit pas si une clé prend effet à chaud ou au redémarrage."));

    racine.replaceChildren(zoneProfils, zoneInstance, zoneTerminal, zoneBilan);
    racine.dataset.modele = JSON.stringify(modele());
    racine.querySelectorAll("textarea").forEach(ajuster);
    const journal = racine.querySelector(".journal");
    journal.scrollTop = journal.scrollHeight;
    // Le curseur reste où le lecteur l’a mis ; une ligne neuve le reçoit.
    const suivi = racine.querySelector(`[data-id="${CSS.escape(focus ?? garde?.id ?? "")}"]:not(:disabled)`);
    if (suivi) {
      suivi.focus();
      if (!focus && suivi.matches("textarea") && garde.debut != null) suivi.setSelectionRange(garde.debut, garde.fin);
    }
  }
  dessiner();
  majRecettes();
})();
