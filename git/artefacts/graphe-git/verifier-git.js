#!/usr/bin/env node
// verifier-git.js — confronte le simulateur au vrai Git.
// Chaque cas est une suite de commandes (commit, branch, switch, merge, rebase, reset) rejouée deux fois : dans le
// simulateur (graphe-git.js, importé tel quel, sans navigateur) et avec le vrai Git, dans un dossier temporaire créé par
// mkdtemp sous le répertoire temporaire du système, avec un HOME factice, une identité factice et des dates fixées
// (une par commande : deux commits ne portent jamais le même identifiant). Aucune commande git ne s'exécute ailleurs :
// le script refuse de démarrer si son dossier de travail se trouve dans un dépôt git, et appelle toujours git avec
// `-C <dossier temporaire>`. Lancez-le depuis un dossier hors de tout dépôt (le répertoire temporaire, par exemple).
// Après chaque commande, il compare, à renommage des commits près (les commits du simulateur sont des lettres) :
//   - le graphe : mêmes parents dans le même ordre (`git rev-list --parents --all --reflog`), mêmes fichiers par commit
//     (`git ls-tree`), et le même ensemble de commits (aucun commit en plus ni en moins) ;
//   - la branche pointée par HEAD (`git symbolic-ref`) et la position de chaque branche (`git for-each-ref`) ;
//   - les commits accessibles depuis une branche (`git rev-list --all`) : les autres sont ceux que le reflog retrouve ;
//   - l'index (`git ls-files`), le répertoire de travail (les fichiers du disque) et `git status --porcelain`.
// Une commande que le simulateur refuse (erreur) doit être refusée par Git ; une commande qu'il déclare hors de son
// champ (« Limitation du simulateur ») n'est pas jouée avec Git, et le simulateur doit alors laisser l'état intact.
// Les cas : les cinq recettes de la page, des cas limites (fusion déjà à jour, avance rapide, rebasage sans rien à
// rejouer, reset sur le commit courant, limitations, erreurs), puis des suites de commandes tirées au hasard avec une graine.
//   node verifier-git.js [--graine N] [--cas N]
// Prérequis : git (≥ 2.28 pour `init -b`) et Node ; aucun droit particulier.
const { spawnSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const S = require("./graphe-git.js");

// ---- Refus de démarrer dans un dépôt git (sans appeler git) ----
function dansUnDepot(dossier) {
  for (let d = path.resolve(dossier); ; d = path.dirname(d)) {
    if (fs.existsSync(path.join(d, ".git"))) return d;
    if (path.dirname(d) === d) return null;
  }
}
const depot = dansUnDepot(process.cwd());
if (depot) { console.error(`Refus : le dossier de travail (${process.cwd()}) est dans le dépôt git ${depot}. Lancez le script depuis un dossier hors de tout dépôt, par exemple ${os.tmpdir()}.`); process.exit(2); }

const arg = (nom, defaut) => { const i = process.argv.indexOf(nom); return i > 0 ? +process.argv[i + 1] : defaut; };
const GRAINE = arg("--graine", 20260), ALEATOIRES = arg("--cas", 400);

// ---- L'environnement de Git : jamais celui de l'utilisateur ----
const RACINE = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-git-"));
const MAISON = path.join(RACINE, "home");
fs.mkdirSync(MAISON);
let pas = 0;   // une date par commande
const env = () => ({
  PATH: process.env.PATH, HOME: MAISON, XDG_CONFIG_HOME: path.join(MAISON, ".config"), GIT_CONFIG_NOSYSTEM: "1", GIT_CONFIG_GLOBAL: path.join(MAISON, ".gitconfig"),
  LC_ALL: "C", LANG: "C", GIT_PAGER: "cat", GIT_TERMINAL_PROMPT: "0", GIT_EDITOR: "true", GIT_MERGE_AUTOEDIT: "no",
  GIT_AUTHOR_NAME: "Ada Lovelace", GIT_AUTHOR_EMAIL: "ada@example.org", GIT_COMMITTER_NAME: "Ada Lovelace", GIT_COMMITTER_EMAIL: "ada@example.org",
  GIT_AUTHOR_DATE: `${1795600000 + 60 * pas} +0000`, GIT_COMMITTER_DATE: `${1795600000 + 60 * pas} +0000`,
});
let dossier;   // le dépôt du cas en cours : toujours sous RACINE
const git = (...a) => spawnSync("git", ["-C", dossier, ...a], { encoding: "utf8", env: env() });
const sortie = (...a) => { const x = git(...a); if (x.status !== 0) throw new Error(`git ${a.join(" ")} : ${x.stderr}`); return x.stdout; };
const lignes = t => t.split("\n").filter(Boolean);

function hasard(graine) { let a = graine >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// ---- Un cas : un dépôt réel et le simulateur, joués ensemble ----
function ouvrir(i) {
  dossier = fs.mkdtempSync(path.join(RACINE, `cas${i}-`));
  pas = 0;
  let x = spawnSync("git", ["-C", dossier, "init", "-q", "-b", "main"], { encoding: "utf8", env: env() });
  if (x.status !== 0) throw new Error(x.stderr);
  fs.writeFileSync(path.join(dossier, "a.txt"), "a.txt\n");
  sortie("add", "a.txt"); pas++;
  sortie("commit", "-q", "-m", "a.txt");
  return { sha: { A: sortie("rev-parse", "HEAD").trim() } };
}

// Joue une commande avec le vrai Git. Rend { statut, erreur } ; met à jour la correspondance nom ↔ SHA.
function rejouer(op, r, etat) {
  pas++;
  const avant = new Set(Object.keys(etat.sha));
  let x;
  if (op.op === "commit") {
    fs.writeFileSync(path.join(dossier, r.fichier ?? ""), `${r.fichier}\n`);
    x = git("add", r.fichier); if (x.status === 0) x = git("commit", "-q", "-m", r.fichier);
  } else if (op.op === "branch") x = git("branch", op.nom);
  else if (op.op === "switch") x = git("switch", "-q", op.nom);
  else if (op.op === "merge") x = git("merge", "-q", "--no-edit", op.nom);
  else if (op.op === "rebase") x = git("rebase", "-q", op.nom);
  else if (op.op === "reset") x = git("reset", "-q", `--${op.mode}`, etat.sha[op.cible] ?? op.cible);
  return x;
}
// Après une commande réussie : les nouveaux commits du simulateur reçoivent le SHA que Git a créé.
function apparier(op, r, etat, avantSha) {
  const nouveaux = r.etat.ordre.filter(n => !r.avant.commits[n]);
  if (!nouveaux.length) return [];
  const ecarts = [];
  const tous = lignes(sortie("rev-list", "--all", "--reflog")).filter(h => !Object.values(etat.sha).includes(h));
  if (op.op === "rebase") {
    // les copies, du plus ancien au plus récent, sont celles que Git a créées au-dessus de la cible
    const cible = etat.sha[r.cible];
    const reel = lignes(sortie("rev-list", "--reverse", `${cible}..HEAD`));
    const copies = r.copies.map(c => c.nouveau);
    if (reel.length !== copies.length) ecarts.push(`rebase : ${reel.length} commits rejoués par Git, ${copies.length} par le simulateur`);
    else copies.forEach((n, i) => { etat.sha[n] = reel[i]; });
  } else if (nouveaux.length === 1) etat.sha[nouveaux[0]] = sortie("rev-parse", "HEAD").trim();
  else ecarts.push(`${nouveaux.length} commits nouveaux (${nouveaux})`);
  if (tous.length !== nouveaux.length) ecarts.push(`Git a créé ${tous.length} commits, le simulateur ${nouveaux.length}`);
  return ecarts;
}

function comparer(e, etat, arbresDeja) {
  const ecarts = [], sha = etat.sha, nom = Object.fromEntries(Object.entries(sha).map(([n, h]) => [h, n]));
  const HEAD = git("symbolic-ref", "--short", "HEAD").stdout.trim();
  if (HEAD !== e.tete) ecarts.push(`HEAD : Git ${HEAD} ≠ simulateur ${e.tete}`);
  const refs = Object.fromEntries(lignes(sortie("for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads")).map(l => l.split(" ")).map(([b, h]) => [b, nom[h] ?? `?${h.slice(0, 7)}`]));
  if (JSON.stringify(Object.entries(refs).sort()) !== JSON.stringify(Object.entries(e.branches).sort())) ecarts.push(`branches : Git ${JSON.stringify(refs)} ≠ simulateur ${JSON.stringify(e.branches)}`);
  // graphe : parents, dans l'ordre
  const reel = Object.fromEntries(lignes(sortie("rev-list", "--parents", "--all", "--reflog")).map(l => l.split(" ")).map(([h, ...ps]) => [nom[h] ?? `?${h.slice(0, 7)}`, ps.map(p => nom[p] ?? `?${p.slice(0, 7)}`)]));
  for (const n of e.ordre) {
    if (!reel[n]) { ecarts.push(`commit ${n} : absent de Git`); continue; }
    if (JSON.stringify(reel[n]) !== JSON.stringify(e.commits[n].parents)) ecarts.push(`parents de ${n} : Git ${JSON.stringify(reel[n])} ≠ simulateur ${JSON.stringify(e.commits[n].parents)}`);
    if (!arbresDeja.has(n)) {
      arbresDeja.add(n);
      const t = lignes(sortie("ls-tree", "-r", "--name-only", sha[n])).sort();
      if (JSON.stringify(t) !== JSON.stringify(S.tri(e.commits[n].arbre))) ecarts.push(`fichiers de ${n} : Git ${t} ≠ simulateur ${e.commits[n].arbre}`);
    }
  }
  for (const n of Object.keys(reel)) if (!e.commits[n]) ecarts.push(`Git a un commit de plus : ${n}`);
  // accessibles : ce que des branches atteignent ; le reste est « perdu » (en tirets), retrouvable par le reflog
  const acc = lignes(sortie("rev-list", "--all")).map(h => nom[h] ?? `?${h}`).sort(), attendu = [...S.accessibles(e)].sort();
  if (JSON.stringify(acc) !== JSON.stringify(attendu)) ecarts.push(`commits accessibles : Git ${acc} ≠ simulateur ${attendu}`);
  // index, répertoire, statut
  const index = lignes(sortie("ls-files")).sort(), disque = fs.readdirSync(dossier).filter(f => f !== ".git").sort();
  if (JSON.stringify(index) !== JSON.stringify(S.tri(e.index))) ecarts.push(`index : Git ${index} ≠ simulateur ${e.index}`);
  if (JSON.stringify(disque) !== JSON.stringify(S.tri(e.rep))) ecarts.push(`répertoire : Git ${disque} ≠ simulateur ${e.rep}`);
  const st = lignes(sortie("status", "--porcelain")).sort(), stSim = S.statut(e);
  if (JSON.stringify(st) !== JSON.stringify(stSim)) ecarts.push(`git status --porcelain : Git ${JSON.stringify(st)} ≠ simulateur ${JSON.stringify(stSim)}`);
  return ecarts;
}

// Joue un cas ; rend les écarts et des statistiques.
const TRACE = process.argv.includes("--trace");
const stats = { cas: 0, commandes: 0, reelles: 0, limites: 0, erreurs: 0, types: {} };
const compte = cle => { stats.types[cle] = (stats.types[cle] ?? 0) + 1; };
function jouerCas(titre, ops, i) {
  const etat = ouvrir(i), arbresDeja = new Set(["A"]);
  let e = S.depart();
  const ecarts = [];
  const note = (op, ...m) => ecarts.push(`${titre} · ${S.commande(e, op)} : ${m.join(" ")}`);
  for (let k = 0; k < ops.length; k++) {
    let op = typeof ops[k] === "function" ? ops[k](e) : ops[k];
    stats.commandes++; if (TRACE) console.log("  >", S.commande(e, op), JSON.stringify(op));
    const r = S.appliquer(e, op);
    // explication : jamais de trou dans le texte
    const texte = S.expliquer(r).join("\n");
    if (/undefined|NaN|\[object|\bnull\b/.test(texte)) note(op, `explication douteuse : ${texte}`);
    if (r.limite) {
      stats.limites++; compte(`limite ${op.op}`);
      if (r.etat !== e && JSON.stringify(r.etat) !== JSON.stringify(e)) note(op, "limite, mais l'état a changé");
      continue;
    }
    if (r.erreur) {
      stats.erreurs++; compte(`erreur ${op.op}`);
      const x = rejouer(op, r, etat);
      if (x.status === 0) note(op, `le simulateur refuse (${r.erreur}), Git accepte`);
      else if (!x.stderr.includes(r.erreur)) note(op, `message : Git « ${x.stderr.trim()} », simulateur « ${r.erreur} »`);
      if (JSON.stringify(r.etat) !== JSON.stringify(e)) note(op, "erreur, mais l'état a changé");
      continue;
    }
    const x = rejouer(op, r, etat);
    stats.reelles++; compte(op.op === "merge" || op.op === "rebase" ? `${op.op} ${r.type}` : op.op === "reset" ? `reset ${op.mode} ${r.relation}` : op.op);
    if (r.ignores?.length) compte("rebase avec commit ignoré");
    if (x.status !== 0) { note(op, `Git a refusé : ${(x.stderr + x.stdout).trim()}`); break; }
    e = r.etat;
    ecarts.push(...apparier(op, r, etat).map(m => `${titre} · ${r.commande} : ${m}`));
    ecarts.push(...comparer(e, etat, arbresDeja).map(m => `${titre} · ${r.commande} : ${m}`));
    if (ecarts.length) break;
  }
  stats.cas++;
  return ecarts;
}

// ---- Les cas ----
const c = { op: "commit" }, br = nom => ({ op: "branch", nom }), sw = nom => ({ op: "switch", nom }), mg = nom => ({ op: "merge", nom }), rb = nom => ({ op: "rebase", nom });
const rs = (mode, cible) => ({ op: "reset", mode, cible });
// Une cible de reset « HEAD~n » : n parents premiers depuis HEAD.
const remonter = n => e => { let x = S.pointe(e); for (let k = 0; k < n; k++) x = e.commits[x].parents[0] ?? x; return rs("mixed", x); };
const cas = [];
for (const [nom, etapes] of Object.entries(S.SCENARIOS)) cas.push([`recette ${nom}`, etapes.flatMap(([, ops]) => ops)]);
cas.push(
  // fusion déjà à jour (même commit, puis ancêtre), sur soi-même
  ["fusion : même commit", [c, br("contact"), mg("contact")]],
  ["fusion : ancêtre", [br("contact"), c, c, mg("contact")]],
  ["fusion : main dans main", [c, mg("main")]],
  ["fusion : avance rapide puis déjà à jour", [br("contact"), sw("contact"), c, c, sw("main"), mg("contact"), mg("contact")]],
  ["fusion : avance rapide à l'envers (main a avancé)", [br("contact"), c, sw("contact"), mg("main")]],
  ["fusion : deux fusions de suite", [br("style"), sw("style"), c, sw("main"), c, mg("style"), sw("style"), mg("main"), c, mg("main")]],
  // rebasage sans rien à rejouer, ou à avance rapide
  ["rebase : cible égale", [br("faq"), sw("faq"), rb("main")]],
  ["rebase : cible ancêtre", [c, br("faq"), c, sw("faq"), rb("main")]],
  ["rebase : avance rapide", [br("faq"), sw("faq"), c, sw("main"), rb("faq")]],
  ["rebase : sur soi-même", [c, rb("main")]],
  ["rebase : un commit", [br("faq"), sw("faq"), c, sw("main"), c, sw("faq"), rb("main")]],
  ["rebase : main sur faq", [br("faq"), sw("faq"), c, sw("main"), c, c, rb("faq")]],
  ["rebase : l'ancien commit reste sur une autre branche", [br("faq"), sw("faq"), c, c, br("style"), sw("main"), c, sw("faq"), rb("main")]],
  ["rebase : deux fois de suite", [br("faq"), sw("faq"), c, sw("main"), c, sw("faq"), rb("main"), sw("main"), c, sw("faq"), rb("main")]],
  ["rebase : commit équivalent déjà en amont (reset vers l'ancien)", [br("faq"), sw("faq"), c, sw("main"), c, sw("faq"), rb("main"), sw("main"), mg("faq"), sw("faq"), rs("hard", "B"), rb("main")]],
  ["rebase : commit déjà appliqué, tout est ignoré", [br("faq"), sw("faq"), c, sw("main"), c, sw("faq"), rb("main"), sw("main"), rs("hard", "A"), c, sw("faq"), rs("hard", "B"), rb("main")]],
  ["rebase : commit de fusion (limitation)", [br("x"), sw("x"), c, sw("main"), c, c, mg("x"), sw("x"), c, rb("main")].map(o => o.nom === "x" ? { ...o, nom: "faq" } : o)],
  ["rebase : main contient une fusion (limitation)", [br("faq"), sw("faq"), c, sw("main"), br("style"), c, sw("style"), c, sw("main"), mg("style"), rb("faq")]],
  // reset sur le commit courant, et partout
  ["reset soft HEAD", [c, rs("soft", "B")]],
  ["reset mixed HEAD", [c, rs("mixed", "B")]],
  ["reset hard HEAD", [c, rs("hard", "B")]],
  ["reset hard HEAD sur A", [rs("hard", "A"), rs("mixed", "A"), rs("soft", "A")]],
  ["reset soft puis mixed sur le même commit", [c, c, rs("soft", "A"), rs("mixed", "A"), rs("hard", "A")]],
  ["reset soft puis commit", [c, c, rs("soft", "B"), c]],
  ["reset mixed puis commit", [c, c, rs("mixed", "B"), c, rs("hard", "B")]],
  ["reset hard puis commit", [c, c, rs("hard", "B"), c]],
  ["reset en avant (vers un commit perdu)", [c, c, rs("hard", "A"), rs("hard", "C")]],
  ["reset en avant, soft", [c, c, rs("hard", "A"), rs("soft", "C")]],
  ["reset en avant, mixed", [c, c, rs("hard", "A"), rs("mixed", "C")]],
  ["reset vers une autre ligne", [br("faq"), sw("faq"), c, sw("main"), c, rs("hard", "B"), rs("soft", "C"), rs("mixed", "B")]],
  ["reset mixed puis hard (fichier non suivi)", [c, c, rs("mixed", "A"), rs("hard", "A"), rs("hard", "C")]],
  ["reset soft puis hard ailleurs", [c, c, rs("soft", "A"), rs("hard", "B")]],
  ["reset d'une branche qui en porte une autre", [br("faq"), c, c, rs("hard", "B"), rs("hard", "A")]],
  // limites : index ou répertoire différents de HEAD
  ["limite : switch après reset mixed", [br("contact"), c, rs("mixed", "A"), sw("contact"), c, sw("contact")]],
  ["limite : merge après reset soft", [br("contact"), sw("contact"), c, sw("main"), c, rs("soft", "A"), mg("contact"), rb("contact")]],
  ["limite : rebase après reset mixed", [br("contact"), sw("contact"), c, sw("main"), c, rs("mixed", "A"), rb("contact")]],
  // limite : fusion « en croix »
  ["limite : fusion en croix", [br("x"), sw("x"), c, sw("main"), c, br("y"), sw("y"), mg("x"), sw("main"), mg("x"), mg("y")].map(o => o.nom === "x" ? { ...o, nom: "faq" } : o.nom === "y" ? { ...o, nom: "style" } : o)],
  // erreurs : nom déjà pris, branche absente
  ["erreur : branche déjà créée", [br("contact"), br("contact"), br("main")]],
  ["erreur : branche absente", [sw("inconnue"), mg("inconnue"), rb("inconnue"), rs("hard", "Z")]],
  ["switch sur la branche courante", [sw("main"), br("contact"), sw("contact"), sw("contact")]],
  ["limite : 14 commits", Array(15).fill(c)],
);
// Les cas à « x » et « y » ci-dessus utilisent des noms de la liste : faq, style.
for (const [t, ops] of cas) for (const o of ops) if (o.nom && !["main", "contact", "style", "faq", "titre", "inconnue"].includes(o.nom)) throw new Error(`${t} : nom de branche ${o.nom}`);

// ---- Suites tirées au hasard ----
function suiteAuHasard(graine) {
  const alea = hasard(graine), choisir = xs => xs[Math.floor(alea() * xs.length)], ops = [], n = 6 + Math.floor(alea() * 14);
  const generateur = e => {
    const propre = S.propre(e), noms = Object.keys(e.branches), libres = S.BRANCHES.filter(b => !e.branches[b]);
    // Les branches qui ont divergé de la branche courante (aucune n'est l'ancêtre de l'autre) donnent les fusions et les
    // rebasages intéressants ; sans elles, on préfère faire des commits et changer de branche.
    const anc = S.ancetres(e, S.pointe(e)), divergentes = noms.filter(b => b !== e.tete && !anc.has(e.branches[b]) && !S.ancetres(e, e.branches[b]).has(S.pointe(e)));
    const devant = noms.filter(b => b !== e.tete && S.ancetres(e, e.branches[b]).has(S.pointe(e)) && e.branches[b] !== S.pointe(e));
    const mr = divergentes.length ? 5 : devant.length ? 1.5 : 0.4;
    const poids = [["commit", propre ? (divergentes.length ? 3 : 5) : 6], ["branch", libres.length ? 2 : 0], ["switch", divergentes.length ? 1.5 : 3], ["merge", mr], ["rebase", mr],
      ["reset", propre ? 2 : 7], ["erreur", 0.15]];
    let t = alea() * poids.reduce((a, [, w]) => a + w, 0), type;
    for (const [k, w] of poids) { if ((t -= w) < 0) { type = k; break; } }
    if (type === "commit") return { op: "commit" };
    if (type === "branch") return { op: "branch", nom: choisir(libres) };
    if (type === "switch") return { op: "switch", nom: choisir(noms) };
    const cibleDe = () => alea() < 0.9 && (divergentes.length || devant.length) ? choisir(divergentes.length && alea() < 0.8 ? divergentes : divergentes.concat(devant).length ? divergentes.concat(devant) : noms) : choisir(noms);
    if (type === "merge") return { op: "merge", nom: cibleDe() };
    if (type === "rebase") return { op: "rebase", nom: cibleDe() };
    if (type === "reset") return { op: "reset", mode: choisir(["soft", "mixed", "hard"]), cible: choisir(e.ordre) };
    return choisir([{ op: "branch", nom: "main" }, { op: "switch", nom: "absente" }, { op: "merge", nom: "absente" }]);
  };
  for (let k = 0; k < n; k++) ops.push(generateur);
  return ops;
}
if (process.argv.includes("--seulement-hasard")) cas.length = 0;
for (let k = 0; k < ALEATOIRES; k++) cas.push([`hasard ${GRAINE + k}`, suiteAuHasard(GRAINE + k)]);

// ---- Les réponses des expériences de la page, relues sur le simulateur ----
// (la comparaison à Git, plus haut, vaut pour le simulateur ; ceci vérifie que les réponses écrites dans la page disent
// ce que le simulateur calcule.)
function verifierReponses() {
  const ecarts = [], jouer = (nom, jusque = Infinity) => {
    let e = S.depart(), dernier, etats = [];
    S.SCENARIOS[nom].forEach(([, ops], i) => { if (i < jusque) ops.forEach(op => { dernier = S.appliquer(e, op); e = dernier.etat; }); etats.push([e, dernier]); });
    return { e, dernier, etats };
  };
  const exige = (nom, cond, texte) => { if (!cond) ecarts.push(`réponse « ${nom} » : ${texte}`); };
  const J = JSON.stringify;
  let { e, dernier } = jouer("pointeurs");
  exige("pointeurs", J(e.branches) === J({ main: "D", contact: "C" }) && e.tete === "main", "main → D, contact → C, HEAD → main");
  exige("pointeurs", J(e.commits.C.parents) === J(["B"]) && J(e.commits.D.parents) === J(["B"]), "C et D ont pour parent B");
  ({ e, dernier } = jouer("avance-rapide"));
  exige("avance-rapide", dernier.type === "avance-rapide" && e.branches.main === "C" && e.ordre.length === 3, "avance rapide jusqu'à C, aucun commit de plus");
  let r = jouer("fusion");
  exige("fusion", J(r.etats[4][0].commits.E.parents) === J(["D", "C"]) && r.etats[4][1].base === "B" && r.etats[4][0].branches.style === "C", "E : parents D puis C, base B, style immobile");
  exige("fusion", r.dernier.type === "a-jour", "la seconde fusion est « déjà à jour »");
  r = jouer("rebasage");
  const reb = r.etats[2][1];
  exige("rebasage", J(reb.copies) === J([{ ancien: "B", nouveau: "E" }, { ancien: "C", nouveau: "F" }]) && J(reb.perdus) === J(["B", "C"]), "B→E, C→F, B et C perdus");
  exige("rebasage", r.dernier.type === "avance-rapide" && r.e.branches.main === "F" && r.e.branches.faq === "F" && r.e.ordre.length === 6, "avance rapide de main jusqu'à F");
  r = jouer("reset");
  const st = i => S.statut(r.etats[i][0]);
  exige("reset", J(st(1)) === J(["A  b.txt"]) && r.etats[1][0].branches.main === "A", "soft : « A  b.txt », main sur A");
  exige("reset", J(st(3)) === J(["?? b.txt"]), "mixed : « ?? b.txt »");
  exige("reset", st(2).length === 0 && r.etats[2][0].branches.main === "B" && st(4).length === 0 && r.etats[4][0].branches.main === "B", "reset --hard B revient à B, propre");
  exige("reset", st(5).length === 0 && r.e.rep.join() === "a.txt" && r.e.branches.main === "A" && !S.accessibles(r.e).has("B"), "hard : plus de b.txt, B perdu");
  return ecarts;
}

// ---- Exécution ----
const version = (spawnSync("git", ["--version"], { encoding: "utf8", env: env() }).stdout || "git ?").trim();
let echecs = 0;
for (const m of verifierReponses()) { echecs++; console.log(`ÉCART  ${m}`); }
try {
  cas.forEach(([titre, ops], i) => {
    const ecarts = jouerCas(titre, ops, i);
    if (ecarts.length) { echecs++; console.log(`ÉCART  ${titre}\n  ${ecarts.slice(0, 4).join("\n  ")}`); }
  });
} finally { fs.rmSync(RACINE, { recursive: true, force: true }); }
const types = Object.entries(stats.types).sort().map(([k, v]) => `${k} ${v}`).join(", ");
console.log(`${version} · ${stats.cas} cas (${ALEATOIRES} au hasard, graine ${GRAINE}), ${stats.commandes} commandes : ${stats.reelles} comparées à Git, ${stats.limites} limitations, ${stats.erreurs} erreurs · ${echecs} cas en écart`);
console.log(`couverture : ${types}`);
process.exit(echecs ? 1 : 0);
