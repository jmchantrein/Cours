#!/usr/bin/env node
// verifier-incus.js — confronte le simulateur au vrai Incus.
// Joue dans la page compilée une suite de manipulations tirées au hasard (clés et périphériques des profils et
// des instances, ordre des profils, override, none, retrait refusé), exécute dans un vrai Incus les commandes
// que le simulateur affiche pour chacune, puis compare, pour chaque instance, la configuration étendue affichée
// à la sortie de `incus config show <instance> --expanded`. Une commande que le simulateur dit refusée doit
// l’être par Incus, avec le même message.
//
// Prérequis : Incus (visé : 6.0.4) initialisé par `incus admin init --minimal` (pool `default`, pont `incusbr0`),
// le droit de lui parler (groupe incus-admin), Node.js et Playwright ; la page compilée à côté du script.
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     virtualisation/artefacts/heritage-des-profils/heritage-des-profils.typ virtualisation/artefacts/heritage-des-profils/index.html
//   node virtualisation/artefacts/heritage-des-profils/verifier-incus.js [nombre de manipulations] [graine] [--garder]
// Ni KVM ni image : les instances sont des conteneurs vides, créés par `incus create --empty` et jamais démarrés
// (la règle d’expansion est la même pour une VM : expandConfig, dans driver_common.go). Tout se passe dans un
// projet à part, `verif-heritage-<pid>`, supprimé à la fin (`--garder` le laisse, pour l’examiner).
// Il tourne en CI, par le workflow .github/workflows/verification-artefacts.yml (runner ubuntu-26.04).
// Le client est lancé avec LC_ALL=C : les messages de refus comparés sont ceux, anglais, du code d’Incus.
// Variables : INCUS (la commande, « incus » par défaut), PAGE (le fichier de la page, chemin absolu).
// Code de retour : 0 sans écart, 1 au premier écart (tout ce qu’il faut pour le rejouer est affiché), 2 si
// l’essai n’a pas pu se faire.
const { chromium } = require("playwright");
const { spawnSync } = require("child_process");
const path = require("path");

const options = process.argv.slice(2).filter(a => a.startsWith("--")), nombres = process.argv.slice(2).filter(a => !a.startsWith("--"));
const manipulations = +(nombres[0] ?? 60);
let graine = +(nombres[1] ?? 20261125);
const INCUS = process.env.INCUS ?? "incus", PAGE = process.env.PAGE ?? path.join(__dirname, "index.html");
const PROJET = `verif-heritage-${process.pid}`;
// Générateur congruentiel : on tire dans les bits de poids fort, les seuls bien mélangés.
const hasard = n => { graine = (graine * 1103515245 + 12345) % 2147483648; return Math.floor(graine / 65536) % n; };
const parmi = liste => liste[hasard(liste.length)];

// Ce que les manipulations écrivent : des clés et des périphériques qu’Incus valide sans rien demander à l’hôte.
// Les valeurs « 2 », « true », « 0001 » sont là exprès : la sortie YAML les met entre guillemets.
const CLES = { "user.a": ["1", "deux", "true"], "user.b": ["x", "0.5"], "limits.cpu": ["1", "2", "4"], "limits.memory": ["512MiB", "1GiB", "2GiB"], "boot.autostart": ["true", "false"] };
const NOMS = ["web", "cle", "port"];
const peutEtre = texte => (hasard(2) ? " " + texte : "");
const PERIPHERIQUES = [
  () => `proxy listen=tcp:127.0.0.1:${8080 + hasard(3)} connect=tcp:127.0.0.1:${80 + hasard(2)}` + peutEtre("bind=host") + peutEtre("user.note=" + parmi(["a", "b"])),
  () => "usb" + peutEtre("vendorid=" + parmi(["0001", "1d6b"])) + peutEtre("productid=0002") + peutEtre("user.note=" + parmi(["a", "b"])),
  () => "none",
];

// ---------- Le vrai Incus ----------
const historique = [];   // toutes les commandes exécutées, pour rejouer un écart à la main
function incus(argv, { projet = true } = {}) {
  const complet = [...(projet ? ["--project", PROJET] : []), ...argv];
  // LC_ALL=C : les messages d’erreur comparés sont ceux du code, en anglais. Entrée fermée : `incus create` la lit.
  const r = spawnSync(INCUS, complet, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, LC_ALL: "C", LANGUAGE: "C" } });
  if (r.error) throw new Error(`impossible de lancer « ${INCUS} » : ${r.error.message}`);
  historique.push(`${INCUS} ${complet.map(a => (/^[\w@%+=:,.\/-]+$/.test(a) ? a : `'${a.replaceAll("'", "'\\''")}'`)).join(" ")}` + (r.status ? `   # code ${r.status} : ${r.stderr.trim().split("\n").at(-1)}` : ""));
  return { ok: r.status === 0, sortie: r.stdout, erreur: r.stderr.trim() };
}
function exiger(argv, quoi, opts) {
  const r = incus(argv, opts);
  if (!r.ok) throw new Error(`${quoi} : « incus ${argv.join(" ")} » a échoué :\n${r.erreur}`);
  return r.sortie;
}

// ---------- Lecture du YAML d’Incus (yaml.v2) : des tables de chaînes sur trois niveaux, des listes de chaînes ----------
function scalaire(v) {
  if (v === "{}") return {};
  if (v === "[]") return [];
  if (v.startsWith('"')) { try { return JSON.parse(v); } catch { return v.slice(1, -1); } }
  if (v.startsWith("'")) return v.slice(1, -1).replaceAll("''", "'");
  return v;
}
// « clé: valeur » → [clé, valeur] ; la clé peut être entre guillemets.
function couper(ligne) {
  const m = ligne.match(/^("(?:[^"\\]|\\.)*"|'(?:[^']|'')*'|[^\s:][^:]*?(?::(?!\s|$)[^:]*?)*):(?:\s+(.*))?$/);
  return m ? [scalaire(m[1]), m[2] ?? ""] : null;
}
function lireYaml(texte) {
  const racine = {}, lignes = texte.split("\n");
  let cle0 = null, table1 = null, table2 = null;
  for (let i = 0; i < lignes.length; i++) {
    const brute = lignes[i], retrait = brute.search(/\S/), contenu = brute.trim();
    if (!contenu || contenu.startsWith("#")) continue;
    // Une valeur sur plusieurs lignes (bloc « | », longue chaîne repliée) : ses lignes de suite, plus en retrait, sont avalées.
    const valeurDe = v => {
      const suites = [], bloc = /^[|>][-+]?$/.test(v);
      while (i + 1 < lignes.length && (lignes[i + 1].trim() === "" ? bloc : lignes[i + 1].search(/\S/) > retrait)) suites.push(lignes[++i].trim());
      return bloc ? suites.join("\n") : scalaire([v, ...suites].join(" "));
    };
    if (retrait === 0 && contenu.startsWith("- ")) { if (Array.isArray(racine[cle0])) racine[cle0].push(scalaire(contenu.slice(2))); continue; }
    const paire = couper(contenu);
    if (!paire) continue;
    const [k, v] = paire;
    if (retrait === 0) { cle0 = k; table2 = null; racine[k] = v === "" ? (lignes[i + 1]?.startsWith("- ") ? [] : {}) : valeurDe(v); table1 = v === "" ? racine[k] : null; }
    else if (retrait === 2 && table1 && !Array.isArray(table1)) { table1[k] = v === "" ? {} : valeurDe(v); table2 = v === "" ? table1[k] : null; }
    else if (retrait === 4 && table2) table2[k] = valeurDe(v);
  }
  return racine;
}
// Les clés qu’Incus tient lui-même, et que le simulateur ne montre pas.
const tenue = k => k.startsWith("volatile.") || k.startsWith("image.");
const propre = yaml => ({
  config: Object.fromEntries(Object.entries(yaml.config ?? {}).filter(([k]) => !tenue(k))),
  devices: yaml.devices ?? {}, profiles: yaml.profiles ?? [],
});
// Les différences entre deux valeurs, en clair : chemin, valeur du simulateur, valeur d’Incus.
function differences(sim, reel, chemin = "") {
  if (typeof sim !== "object" || typeof reel !== "object" || sim === null || reel === null || Array.isArray(sim) !== Array.isArray(reel))
    return JSON.stringify(sim) === JSON.stringify(reel) ? [] : [`${chemin.replace(/ › $/, "")} : simulateur ${JSON.stringify(sim)}, Incus ${JSON.stringify(reel)}`];
  return [...new Set([...Object.keys(sim), ...Object.keys(reel)])].sort().flatMap(k =>
    !(k in sim) ? [`${chemin}${k} : absent du simulateur, Incus ${JSON.stringify(reel[k])}`]
      : !(k in reel) ? [`${chemin}${k} : simulateur ${JSON.stringify(sim[k])}, absent d’Incus`]
      : Array.isArray(sim[k]) ? differences(JSON.stringify(sim[k]), JSON.stringify(reel[k]), `${chemin}${k}`)
      : differences(sim[k], reel[k], `${chemin}${k} › `));
}
// La forme : les lignes des rubriques config, devices et profiles, telles qu’Incus les écrit (ordre, guillemets).
function lignesUtiles(texte) {
  const sortie = [];
  let garder = false, saute = -1;
  for (const ligne of texte.split("\n")) {
    const retrait = ligne.search(/\S/);
    if (retrait === 0 && !ligne.startsWith("- ")) garder = /^(config|devices|profiles):/.test(ligne);
    if (!garder || !ligne.trim()) continue;
    if (saute >= 0 && retrait > saute) continue;   // suite d’une valeur de clé tenue par Incus
    saute = -1;
    const paire = retrait === 2 ? couper(ligne.trim()) : null;
    if (paire && tenue(paire[0])) { saute = retrait; continue; }
    sortie.push(ligne.trimEnd());
  }
  // Sans clé propre, Incus écrit encore « config: » (il reste les clés volatile.*) : le simulateur écrit « config: {} ».
  return sortie.map((l, i) => (l === "config:" && !sortie[i + 1]?.startsWith("  ") ? "config: {}" : l));
}

(async () => {
  let navigateur, cree = false, code = 0;
  const nettoyer = () => {
    if (!cree || options.includes("--garder")) { if (cree) console.log(`Projet gardé : ${PROJET} (à supprimer par « incus project delete --force ${PROJET} »).`); return; }
    cree = false;
    // `project delete --force` supprime le projet et ce qu’il contient ; à défaut, on vide le projet d’abord.
    if (incus(["project", "delete", "--force", PROJET], { projet: false }).ok) return;
    for (const n of incus(["list", "-c", "n", "-f", "csv"]).sortie.split("\n").filter(Boolean)) incus(["delete", "--force", n]);
    for (const p of incus(["profile", "list", "-c", "n", "-f", "csv"]).sortie.split("\n").filter(x => x && x !== "default")) incus(["profile", "delete", p]);
    if (!incus(["project", "delete", PROJET], { projet: false }).ok) console.error(`Le projet ${PROJET} n’a pas pu être supprimé : « incus project delete --force ${PROJET} ».`);
  };
  process.on("SIGINT", () => { nettoyer(); process.exit(130); });
  try {
    const version = exiger(["version"], "Incus ne répond pas", { projet: false }).trim().replace(/\n/g, " ; ");
    navigateur = await chromium.launch();
    const page = await navigateur.newPage({ viewport: { width: 1366, height: 800 } });
    await page.goto("file://" + PAGE);
    const modele = async () => JSON.parse(await page.locator("#artefact").getAttribute("data-modele"));
    const depart = await modele();

    // Le départ du simulateur, reproduit dans un projet à part : ses profils, puis ses instances, vides et arrêtées.
    const tous = Object.values(depart.profils).flatMap(p => Object.values(p.devices));
    for (const pool of new Set(tous.filter(d => d.type === "disk" && d.pool).map(d => d.pool))) exiger(["storage", "show", pool], `le pool de stockage « ${pool} » manque (incus admin init --minimal le crée)`, { projet: false });
    for (const reseau of new Set(tous.filter(d => d.type === "nic" && d.network).map(d => d.network))) exiger(["network", "show", reseau], `le réseau « ${reseau} » manque (incus admin init --minimal le crée)`, { projet: false });
    exiger(["project", "create", PROJET], "création du projet d’essai", { projet: false });
    cree = true;
    const paires = o => Object.entries(o).filter(([k]) => k !== "type").map(([k, v]) => `${k}=${v}`);
    for (const [nom, p] of Object.entries(depart.profils)) {
      if (nom !== "default") exiger(["profile", "create", nom], "création d’un profil");
      if (Object.keys(p.config).length) exiger(["profile", "set", nom, ...paires(p.config)], "clés d’un profil");
      for (const [d, cles] of Object.entries(p.devices)) exiger(["profile", "device", "add", nom, d, cles.type, ...paires(cles)], "périphérique d’un profil");
    }
    for (const [nom, i] of Object.entries(depart.instances)) {
      exiger(["create", "--empty", nom, ...i.profils.flatMap(p => ["--profile", p]), ...paires(i.config).flatMap(c => ["--config", c])], "création d’une instance vide");
      for (const [d, cles] of Object.entries(i.devices)) exiger(["config", "device", "add", nom, d, cles.type, ...paires(cles)], "périphérique d’une instance");
    }
    console.log(`Incus : ${version}. Projet d’essai : ${PROJET}. ${manipulations} manipulations, graine ${graine}.`);

    // ---------- La page ----------
    const du = c => (c.genre === "profil" ? `du profil ${c.nom}` : `de l’instance ${c.nom}`), au = c => (c.genre === "profil" ? `au profil ${c.nom}` : `à l’instance ${c.nom}`);
    const couche = (m, c) => (c.genre === "profil" ? m.profils : m.instances)[c.nom];
    const clic = nom => page.getByRole("button", { name: nom, exact: true }).click();
    const saisir = async (etiquette, texte) => { const champ = page.getByLabel(etiquette, { exact: true }); await champ.fill(texte); await champ.press("Enter"); };
    // Écrit une ligne dans une couche : sur la ligne qui porte déjà ce nom, ou sur une ligne neuve.
    async function ecrire(m, c, sorte, nom, texte) {
      const noms = Object.keys(couche(m, c)[sorte]), i = noms.indexOf(nom), quoi = sorte === "config" ? "Clé" : "Périphérique";
      if (i < 0) await clic(`Ajouter ${sorte === "config" ? "une clé" : "un périphérique"} ${au(c)}`);
      await saisir(`${quoi} ${(i < 0 ? noms.length : i) + 1} ${du(c)}`, texte);
    }
    const estRacine = d => d.type === "disk" && d.path === "/" && !d.source;
    // Tire une manipulation que le vrai Incus doit accepter (sauf « retrait refusé », qu’il doit refuser).
    // Jamais touchés : le disque racine et les lignes eth0 et root des profils. Rend sa description.
    async function manipuler() {
      const m = await modele(), n = m.courante, inst = m.instances[n];
      const couches = [...inst.profils.map(nom => ({ genre: "profil", nom })), { genre: "instance", nom: n }];
      const herites = Object.keys(inst.etendue.devices).filter(d => !(d in inst.devices));
      const essais = [
        ["clé", 5, async () => { const c = parmi(couches), k = parmi(Object.keys(CLES)), v = parmi(CLES[k]); await ecrire(m, c, "config", k, `${k}=${v}`); return `${k}=${v} ${du(c)}`; }],
        ["retirer une clé", 2, async () => {
          const c = parmi(couches.filter(x => Object.keys(couche(m, x).config).length)); if (!c) return null;
          const k = parmi(Object.keys(couche(m, c).config)); await clic(`Retirer ${k} ${du(c)}`); return `${k} retirée ${du(c)}`; }],
        ["périphérique", 5, async () => { const c = parmi(couches), d = parmi(NOMS), texte = `${d} ${parmi(PERIPHERIQUES)()}`; await ecrire(m, c, "devices", d, texte); return `« ${texte} » ${du(c)}`; }],
        ["retirer un périphérique", 2, async () => {
          const possibles = couches.flatMap(c => Object.keys(couche(m, c).devices).filter(d => NOMS.includes(d) || (c.genre === "instance" && d === "eth0")).map(d => [c, d]));
          if (!possibles.length) return null;
          const [c, d] = parmi(possibles); await clic(`Retirer ${d} ${du(c)}`); return `${d} retiré ${du(c)}`; }],
        ["ajouter un profil", 2, async () => { const p = parmi(Object.keys(m.profils).filter(x => !inst.profils.includes(x))); if (!p) return null; await clic(`Ajouter le profil ${p} à ${n}`); return `profil ${p} ajouté à ${n}`; }],
        ["déplacer un profil", 3, async () => {
          if (inst.profils.length < 2) return null;
          const i = hasard(inst.profils.length), monte = i > 0 && (i === inst.profils.length - 1 || hasard(2));
          await clic(`${monte ? "Monter" : "Descendre"} le profil ${inst.profils[i]}`); return `profil ${inst.profils[i]} ${monte ? "monté" : "descendu"} dans ${n}`; }],
        ["retirer un profil", 1, async () => {
          // L’instance doit garder un disque racine : par elle-même, ou par un profil qui lui reste.
          const garde = p => Object.values(inst.devices).some(estRacine) || inst.profils.filter(x => x !== p).some(x => Object.values(m.profils[x].devices).some(estRacine));
          const p = parmi(inst.profils.filter(garde)); if (!p) return null;
          await clic(`Retirer le profil ${p} de ${n}`); return `profil ${p} retiré de ${n}`; }],
        ["autre instance", 2, async () => { const x = parmi(Object.keys(m.instances).filter(y => y !== n)); await clic(x); return `afficher ${x}`; }],
        ["override", 2, async () => { const d = parmi(herites); if (!d) return null; await clic(`Surcharger ${d} dans ${n}`); return `override de ${d} dans ${n}`; }],
        ["none", 1, async () => { const d = parmi(herites.filter(x => !estRacine(inst.etendue.devices[x]))); if (!d) return null; await clic(`Remplacer ${d} par un périphérique none dans ${n}`); return `${d} remplacé par none dans ${n}`; }],
        ["retrait refusé", 1, async () => { const d = parmi(herites); if (!d) return null; await clic(`Retirer ${d} de ${n}`); return `retrait de ${d}, hérité, tenté dans ${n}`; }],
      ];
      for (;;) {
        let tirage = hasard(essais.reduce((s, e) => s + e[1], 0));
        const essai = essais.find(e => (tirage -= e[1]) < 0), fait = await essai[2]();
        if (fait) return fait;
      }
    }
    // Les commandes que la page a écrites depuis le rang `depuis` : { n, argv, erreur }.
    const commandes = async depuis => (await page.locator(".journal li[data-n]").evaluateAll(l => l.map(e => ({ n: +e.dataset.n, argv: JSON.parse(e.dataset.argv), erreur: e.dataset.erreur ?? null }))))
      .filter(c => c.n > depuis);
    // Compare, pour chaque instance, ce que la page affiche à ce qu’Incus répond. Rend les écarts et les remarques de forme.
    async function comparer() {
      const ecarts = [], formes = [], affichee = (await modele()).courante;
      for (const n of [affichee, ...Object.keys(depart.instances).filter(x => x !== affichee)]) {
        if ((await modele()).courante !== n) await clic(n);
        const simule = (await page.locator(".yaml-lignes code.yaml").allTextContents()).join("\n");
        const r = incus(["config", "show", n, "--expanded"]);
        if (!r.ok) { ecarts.push({ instance: n, lignes: [`incus config show a échoué : ${r.erreur}`] }); continue; }
        const d = differences(propre(lireYaml(simule)), propre(lireYaml(r.sortie)));
        if (d.length) ecarts.push({ instance: n, lignes: d, simule, reel: r.sortie });
        else if (lignesUtiles(simule).join("\n") !== lignesUtiles(r.sortie).join("\n")) formes.push({ instance: n, simule: lignesUtiles(simule), reel: lignesUtiles(r.sortie) });
      }
      if ((await modele()).courante !== affichee) await clic(affichee);   // la page revient à l’instance qu’elle montrait
      return { ecarts, formes };
    }

    let vues = 0, nFormes = 0;
    const rapporter = async (rang, action, cmds) => {
      const { ecarts, formes } = await comparer();
      console.log(`${String(rang).padStart(3)}. ${ecarts.length ? "ÉCART " : "accord"} | ${action}`);
      for (const c of cmds) console.log(`       $ incus ${c.argv.join(" ")}${c.erreur ? `   → refusée par les deux : ${c.erreur}` : ""}`);
      for (const f of formes) {
        nFormes++;
        console.log(`     forme (${f.instance}) : mêmes valeurs, mais des lignes s’écrivent autrement :`);
        const max = Math.max(f.simule.length, f.reel.length);
        for (let i = 0; i < max; i++) if (f.simule[i] !== f.reel[i]) console.log(`       simulateur « ${f.simule[i] ?? ""} » | Incus « ${f.reel[i] ?? ""} »`);
      }
      for (const e of ecarts) {
        console.log(`     ${e.instance} :`); for (const l of e.lignes) console.log(`       ${l}`);
        if (e.simule) console.log(`     --- simulateur (${e.instance})\n${e.simule}\n     --- incus config show ${e.instance} --expanded\n${e.reel}`);
      }
      return ecarts.length;
    };
    const echouer = async raison => {
      code = 1;
      console.log(`\nÉCART : ${raison}`);
      console.log("\nModèle du simulateur :\n" + JSON.stringify(await modele(), null, 1));
      console.log("\nPour rejouer à la main, toutes les commandes exécutées :\n  " + historique.filter(h => !/ config show /.test(h)).join("\n  "));
    };

    if (await rapporter(0, "départ : l’exemple des diapos", [])) await echouer("le départ du simulateur n’est pas celui d’Incus");
    for (let rang = 1; rang <= manipulations && !code; rang++) {
      const action = await manipuler(), cmds = await commandes(vues);
      vues = Math.max(vues, ...cmds.map(c => c.n));
      // Les commandes affichées par le simulateur, exécutées telles quelles.
      let faute = null;
      for (const c of cmds) {
        const r = incus(c.argv);
        if (c.erreur && r.ok) faute = `le simulateur dit « incus ${c.argv.join(" ")} » refusée (${c.erreur}), Incus l’accepte`;
        else if (c.erreur && !r.erreur.includes(c.erreur.replace(/^Error: /, ""))) faute = `« incus ${c.argv.join(" ")} » est refusée par les deux, mais pas avec le même message : simulateur « ${c.erreur} », Incus « ${r.erreur} »`;
        else if (!c.erreur && !r.ok) faute = `Incus refuse « incus ${c.argv.join(" ")} », que le simulateur accepte : ${r.erreur}`;
        if (faute) break;
      }
      if (faute) { console.log(`${String(rang).padStart(3)}. ÉCART  | ${action}`); await echouer(faute); break; }
      if (await rapporter(rang, action, cmds)) await echouer(`après « ${action} », la configuration étendue du simulateur n’est pas celle d’Incus`);
    }
    if (!code) console.log(`\n${manipulations} manipulations comparées à Incus (${version}) : aucun écart` + (nFormes ? `, ${nFormes} remarque(s) de forme (YAML écrit autrement, mêmes valeurs).` : "."));
  } catch (e) {
    console.error("ÉCHEC :", e.message);
    if (historique.length) console.error("Commandes exécutées :\n  " + historique.join("\n  "));
    code = 2;
  } finally {
    await navigateur?.close();
    nettoyer();
  }
  process.exit(code);
})();
