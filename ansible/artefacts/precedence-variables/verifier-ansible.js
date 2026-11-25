#!/usr/bin/env node
// verifier-ansible.js — confronte le simulateur au vrai Ansible.
// Pour chaque cas, écrit un petit projet dans un dossier temporaire (inventaire YAML, group_vars/, host_vars/, un rôle
// avec defaults/ et vars/, un playbook avec vars:, un bloc, une tâche, un set_fact) et lance le vrai Ansible sur
// localhost, en connexion locale (aucun nœud distant) :
//   - ansible-inventory --host : ce que l'inventaire décide, comparé à simuler(état, "inventaire") ;
//   - ansible-playbook, avec une tâche debug : la valeur que voit l'hôte, comparée à simuler(état).
// Les cas :
//   - les diapos : les fichiers du labo (ansible/cm/labo/projet/demo-groupes et exercice) rejoués tels quels, et
//     leurs équivalents dans le modèle de l'artefact (groupes bdd, nouveaux, prod, web), avec la valeur que la diapo annonce ;
//   - chaque paire de sources voisines dans l'ordre (defaults < all < groupe < sous-groupe < host_vars < play < vars/ du
//     rôle < bloc < tâche < set_fact < -e, puis profondeur, priorité, alphabet) : seules ces deux sources, la plus forte gagne ;
//   - les états de chaque recette de la page ;
//   - des combinaisons tirées au hasard avec une graine (arbre de groupes, membres, fichiers, priorités, sources) ;
//   - un cycle de groupes, qu'Ansible refuse.
// Chaque cas est « épluché » : on rejoue Ansible en retirant la source qui gagne, puis la suivante, etc. ; le gagnant
// de chaque épluchage doit être la source suivante du classement du simulateur. Le classement complet est ainsi vérifié.
//
// Prérequis : Docker, Node.js. L'image de contrôle est celle du labo (ansible/cm/labo/Dockerfile.control : ansible-core
// 2.19.4 par pip sur Debian 13), construite sous le nom artefact-ansible-control si elle manque ; derrière un proxy
// HTTPS qui réécrit TLS, comme ansible/cm/labo/proxy.sh : TPTEST_CA=/chemin/ca.crt HTTPS_PROXY=http://hôte:port.
//   node ansible/artefacts/precedence-variables/verifier-ansible.js [--graine N] [--aleatoires N] [--supprimer-image]
// Il ne touche qu'à son conteneur (artefact-ansible-verif) et à ses images (artefact-ansible-*) ; aucun prune.
const { spawn, spawnSync, execFileSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const m = require("./precedence-variables.js");
const { simuler, depart, vide, etatDe, GROUPES, SOURCES, ORDRE_SOURCES, HOTE, VARIABLE, RECETTES_ETATS } = m;

const IMAGE = "artefact-ansible-control", CONTENEUR = "artefact-ansible-verif";
const LABO = path.resolve(__dirname, "../../cm/labo");
const arg = (nom, defaut) => { const i = process.argv.indexOf(nom); return i < 0 ? defaut : Number(process.argv[i + 1]); };
const GRAINE = arg("--graine", 20260), ALEATOIRES = arg("--aleatoires", 40);

const docker = (args, options = {}) => spawnSync("docker", args, { encoding: "utf8", ...options });

// ---------- L'image de contrôle ----------
function preparerImage() {
  if (docker(["image", "inspect", IMAGE]).status === 0) return;
  console.log(`Construction de ${IMAGE} (Dockerfile.control du labo)…`);
  const args = ["build", "-q", "-t", IMAGE, "-f", path.join(LABO, "Dockerfile.control")];
  if (process.env.TPTEST_CA) {   // la même base que labo/proxy.sh : debian:13-slim qui passe par le proxy
    const proxy = process.env.HTTPS_PROXY;
    if (!proxy) throw new Error("TPTEST_CA demande aussi HTTPS_PROXY");
    const base = fs.mkdtempSync(path.join(os.tmpdir(), "artefact-ansible-base-"));
    fs.copyFileSync(process.env.TPTEST_CA, path.join(base, "ca.crt"));
    fs.writeFileSync(path.join(base, "Dockerfile"), `FROM debian:13-slim
COPY ca.crt /usr/local/share/ca-certificates/proxy.crt
RUN sed -i 's,http://,https://,g' /etc/apt/sources.list.d/debian.sources \\
 && printf 'Acquire::https::Proxy "%s";\\nAcquire::https::CAInfo "/usr/local/share/ca-certificates/proxy.crt";\\n' "${proxy}" > /etc/apt/apt.conf.d/99proxy
`);
    const b = docker(["build", "-q", "-t", "artefact-ansible-base", base]);
    fs.rmSync(base, { recursive: true });
    if (b.status !== 0) throw new Error("base : " + b.stderr);
    args.push("--network", "host", "--build-arg", `HTTPS_PROXY=${proxy}`, "--build-context", "debian:13-slim=docker-image://artefact-ansible-base");
  }
  const r = docker([...args, LABO]);
  if (r.status !== 0) throw new Error("docker build a échoué :\n" + r.stderr);
}

// ---------- Le projet d'un état ----------
const jsonYaml = x => JSON.stringify(x, null, 1);   // le JSON est du YAML
function ecrireProjet(e, dossier) {
  fs.mkdirSync(path.join(dossier, "inv/group_vars"), { recursive: true });
  fs.mkdirSync(path.join(dossier, "inv/host_vars"), { recursive: true });
  const ecrire = (chemin, contenu) => { fs.mkdirSync(path.dirname(path.join(dossier, chemin)), { recursive: true }); fs.writeFileSync(path.join(dossier, chemin), contenu); };
  // L'inventaire : les groupes emboîtés selon l'arbre ; ansible_group_priority s'écrit dans l'inventaire.
  const noeud = g => {
    const n = {};
    const enfants = GROUPES.filter(h => e.parents[h] === g);
    if (enfants.length) n.children = Object.fromEntries(enfants.map(h => [h, noeud(h)]));
    if (e.membres.includes(g)) n.hosts = { [HOTE]: null };
    if (e.priorites[g] !== 1) n.vars = { ansible_group_priority: e.priorites[g] };
    return n;
  };
  const racine = { children: Object.fromEntries(GROUPES.filter(g => e.parents[g] === "all").map(g => [g, noeud(g)])) };
  if (!e.membres.length) racine.hosts = { [HOTE]: null };
  ecrire("inv/hosts.yaml", jsonYaml({ all: racine }));
  const valeur = v => jsonYaml({ [VARIABLE]: v });
  if (e.sources.includes("all")) ecrire("inv/group_vars/all.yaml", valeur(SOURCES.all.valeur));
  for (const g of e.fichiers) ecrire(`inv/group_vars/${g}.yaml`, valeur(g));
  if (e.sources.includes("host")) ecrire(`inv/host_vars/${HOTE}.yaml`, valeur(SOURCES.host.valeur));
  // Le rôle et le playbook.
  const role = e.sources.includes("defaults") || e.sources.includes("rolevars");
  if (role) {
    ecrire("roles/r/tasks/main.yml", "[]\n");
    if (e.sources.includes("defaults")) ecrire("roles/r/defaults/main.yml", valeur(SOURCES.defaults.valeur));
    if (e.sources.includes("rolevars")) ecrire("roles/r/vars/main.yml", valeur(SOURCES.rolevars.valeur));
  }
  const debug = { "ansible.builtin.debug": { msg: `RESULTAT[{{ ${VARIABLE} | default('INDEFINI') }}]` } };
  if (e.sources.includes("tache")) debug.vars = { [VARIABLE]: SOURCES.tache.valeur };
  const taches = [];
  if (e.sources.includes("setfact")) taches.push({ "ansible.builtin.set_fact": { [VARIABLE]: SOURCES.setfact.valeur } });
  taches.push(e.sources.includes("bloc") ? { block: [debug], vars: { [VARIABLE]: SOURCES.bloc.valeur } } : debug);
  const play = { hosts: HOTE, connection: "local", gather_facts: false, tasks: taches };
  if (e.sources.includes("play")) play.vars = { [VARIABLE]: SOURCES.play.valeur };
  if (role) play.roles = ["r"];
  ecrire("play.yml", jsonYaml([play]));
}

// ---------- Exécution : un conteneur, plusieurs commandes en parallèle ----------
function executer(cmd, cwd) {
  return new Promise(fini => {
    const p = spawn("docker", ["exec", "-w", cwd, "-e", "ANSIBLE_LOCALHOST_WARNING=false", "-e", "ANSIBLE_NOCOLOR=1", CONTENEUR, "sh", "-c", cmd]);
    let sortie = "";
    p.stdout.on("data", d => { sortie += d; }); p.stderr.on("data", d => { sortie += d; });
    p.on("close", code => fini({ code, sortie }));
  });
}
async function enParallele(taches, n, progres) {
  let i = 0, faites = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (i < taches.length) { const t = taches[i++]; await t(); progres?.(++faites, taches.length); }
  }));
}
const cle = (e, extra) => JSON.stringify([e.parents, e.membres, e.priorites, [...e.fichiers].sort(), [...e.sources].sort(), extra]);
const memo = new Map();   // état → résultat réel (les épluchages se recoupent)
let compteur = 0, dossierTmp;
// Ce qu'Ansible décide : l'inventaire seul, ou le playbook ; valeur null si la variable est indéfinie.
function reel(mode, e, extra = false) {
  const k = mode + cle(e, extra);
  if (!memo.has(k)) {
    memo.set(k, (async () => {
      const id = `p${++compteur}`, dossier = path.join(dossierTmp, id);
      ecrireProjet(e, dossier);
      if (mode === "inventaire") {
        const r = await executer(`ansible-inventory -i inv/hosts.yaml --host ${HOTE}`, `/w/${id}`);
        try { return { valeur: JSON.parse(r.sortie.slice(r.sortie.indexOf("{")))[VARIABLE] ?? null, sortie: r.sortie }; }
        catch { return { erreur: r.sortie }; }
      }
      const r = await executer(`ansible-playbook -i inv/hosts.yaml play.yml${extra ? ` -e ${VARIABLE}=${SOURCES.extra.valeur}` : ""}`, `/w/${id}`);
      const t = /RESULTAT\[(.*?)\]/.exec(r.sortie);
      return t ? { valeur: t[1] === "INDEFINI" ? null : t[1], sortie: r.sortie } : { erreur: r.sortie };
    })());
  }
  return memo.get(k);
}
// -e n'est pas un fichier : c'est une option de ansible-playbook.
const sansExtra = e => ({ ...e, sources: e.sources.filter(s => s !== "extra") });

// ---------- Les cas ----------
const cas = [];
const ajouter = (nom, e, options = {}) => cas.push({ nom, e: { ...vide(), ...e, sources: e.sources ?? [], fichiers: e.fichiers ?? [], membres: e.membres ?? [] }, ...options });
const groupes = (parents, priorites = {}) => ({ parents: { ...vide().parents, ...parents }, priorites: { ...vide().priorites, ...priorites } });

// 1. Les diapos : équivalents dans le modèle (mon_groupe → prod, web_server → web ; l'exercice du parc).
ajouter("diapo groupes 1 : deux groupes frères, alphabet", { ...groupes({ web: "all" }), membres: ["prod", "web"], fichiers: ["prod", "web"] }, { attendu: "web" });
ajouter("diapo groupes 2 : priorité 10 pour prod", { ...groupes({ web: "all" }, { prod: 10 }), membres: ["prod", "web"], fichiers: ["prod", "web"] }, { attendu: "prod" });
ajouter("diapo groupes 3 : prod enfant de web", { ...groupes({ web: "all", prod: "web" }), membres: ["prod"], fichiers: ["prod", "web"] }, { attendu: "prod" });
const exo = { fichiers: ["bdd", "nouveaux", "prod"], sources: ["all"] };
ajouter("diapo exercice : web1 (host_vars)", { ...exo, membres: ["web"], sources: ["all", "host"], fichiers: ["bdd", "nouveaux", "prod"] }, { attendu: "host_vars" });
ajouter("diapo exercice : web2 (prod)", { ...exo, membres: ["web", "nouveaux"] }, { attendu: "prod" });
ajouter("diapo exercice : bdd1 (bdd)", { ...exo, membres: ["bdd", "nouveaux"] }, { attendu: "bdd" });
ajouter("diapo exercice : web1 avec vars: du play", { ...exo, membres: ["web"], sources: ["all", "host", "play"] }, { attendu: "play" });
ajouter("diapo précédence : play puis -e", { sources: ["all", "host", "play"] }, { attendu: "play" });
ajouter("diapo précédence : -e", { sources: ["all", "host", "play", "extra"] }, { attendu: "extra" });

// 2. Chaque paire de sources voisines.
{
  const arbre = groupes({}, {});
  const positions = [   // de la plus faible à la plus forte, dans le parc de l'exercice (prod, web enfant de prod)
    ["defaults", { sources: ["defaults"] }], ["all", { sources: ["all"] }],
    ["group_vars/prod (profondeur 1)", { fichiers: ["prod"] }], ["group_vars/web (profondeur 2)", { fichiers: ["web"] }],
    ["host_vars", { sources: ["host"] }], ["play", { sources: ["play"] }], ["vars/ du rôle", { sources: ["rolevars"] }],
    ["bloc", { sources: ["bloc"] }], ["tâche", { sources: ["tache"] }], ["set_fact", { sources: ["setfact"] }], ["-e", { sources: ["extra"] }],
  ];
  const union = (a, b) => ({ ...arbre, membres: ["web"], sources: [...(a.sources ?? []), ...(b.sources ?? [])], fichiers: [...(a.fichiers ?? []), ...(b.fichiers ?? [])] });
  for (let i = 1; i < positions.length; i++) {
    ajouter(`paire : ${positions[i - 1][0]} < ${positions[i][0]}`, union(positions[i - 1][1], positions[i][1]), { fort: positions[i][0] });
  }
  // Entre groupes frères (prod, nouveaux, de même profondeur) : l'alphabet, la priorité, puis la priorité contre la profondeur.
  ajouter("paire : alphabet (nouveaux < prod)", { ...arbre, membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"] }, { attendu: "prod" });
  ajouter("paire : priorité (prod 1 < nouveaux 2)", { ...groupes({}, { nouveaux: 2 }), membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"] }, { attendu: "nouveaux" });
  ajouter("paire : priorité égale (10, 10) → alphabet", { ...groupes({}, { nouveaux: 10, prod: 10 }), membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"] }, { attendu: "prod" });
  ajouter("paire : priorité 0 contre priorité par défaut", { ...groupes({}, { prod: 0 }), membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"] }, { attendu: "nouveaux" });
  ajouter("paire : priorité négative contre 0", { ...groupes({}, { prod: -3, nouveaux: 0 }), membres: ["prod", "nouveaux"], fichiers: ["prod", "nouveaux"] }, { attendu: "nouveaux" });
  ajouter("paire : la profondeur bat la priorité", { ...groupes({}, { prod: 100 }), membres: ["web"], fichiers: ["prod", "web"] }, { attendu: "web" });
  ajouter("paire : un enfant bat son parent malgré l'alphabet", { ...groupes({ web: "all", prod: "web" }), membres: ["prod"], fichiers: ["prod", "web"] }, { attendu: "prod" });
  ajouter("paire : profondeur 3 contre profondeur 2", { ...groupes({ bdd: "web" }), membres: ["bdd", "nouveaux"], fichiers: ["bdd", "web", "nouveaux", "prod"] }, { attendu: "bdd" });
  ajouter("paire : groupe sans l'hôte ignoré", { ...groupes({}), membres: ["web"], fichiers: ["bdd", "nouveaux"] }, { attendu: null });
  ajouter("paire : ancêtre sans fichier propre", { ...groupes({}), membres: ["web"], fichiers: ["prod"] }, { attendu: "prod" });
  ajouter("aucune source", { ...groupes({}), membres: [] }, { attendu: null });
}

// 3. Les états des recettes de la page.
for (const [nom, etapes] of Object.entries(RECETTES_ETATS)) etapes.forEach(([titre, ch], i) => cas.push({ nom: `recette ${nom}, étape ${i + 1}`, e: etatDe(ch) }));

// 4. Des combinaisons au hasard.
{
  let s = GRAINE;
  const hasard = () => { s = (s + 0x6D2B79F5) | 0; let t = Math.imul(s ^ (s >>> 15), 1 | s); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const choix = liste => liste[Math.floor(hasard() * liste.length)];
  for (let n = 1; n <= ALEATOIRES; n++) {
    const ordre = [...GROUPES].sort(() => hasard() - .5), parents = {};
    ordre.forEach((g, i) => { parents[g] = i === 0 || hasard() < .35 ? "all" : choix(ordre.slice(0, i)); });
    const priorites = Object.fromEntries(GROUPES.map(g => [g, choix([1, 1, 1, 1, 2, 10, 5, 0, -3, 100])]));
    cas.push({ nom: `hasard ${n} (graine ${GRAINE})`, e: {
      parents, priorites, membres: GROUPES.filter(() => hasard() < .45), fichiers: GROUPES.filter(() => hasard() < .65),
      sources: ORDRE_SOURCES.filter(() => hasard() < .5) } });
  }
}

// ---------- Programme ----------
(async () => {
  preparerImage();
  dossierTmp = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-ansible-"));
  docker(["rm", "-f", CONTENEUR]);
  const lancement = docker(["run", "-d", "--name", CONTENEUR, "-v", `${dossierTmp}:/w`, "-v", `${LABO}:/labo:ro`, IMAGE, "sleep", "infinity"]);
  if (lancement.status !== 0) throw new Error(lancement.stderr);
  const nettoyer = () => { docker(["rm", "-f", CONTENEUR]); fs.rmSync(dossierTmp, { recursive: true, force: true }); };
  process.on("SIGINT", () => { nettoyer(); process.exit(130); });
  try {
    const version = (await executer("ansible --version | head -1", "/")).sortie.trim();
    const python = (await executer("ansible --version | grep 'python version'", "/")).sortie.trim();
    let ecarts = 0, comparaisons = 0;
    const signaler = (nom, texte) => { ecarts++; console.log(`ÉCART  ${nom}\n         ${texte}`); };
    const comparer = (nom, quoi, vrai, sim) => { comparaisons++; if (vrai !== sim) signaler(nom, `${quoi} : Ansible ${JSON.stringify(vrai)} ≠ simulateur ${JSON.stringify(sim)}`); };

    // Les fichiers des diapos, rejoués tels quels (labo monté en lecture seule).
    const tel = [
      ["labo demo-groupes/hosts.yaml", "cd /labo/projet/demo-groupes && ansible-inventory -i hosts.yaml --host managed-node-1", "web_server"],
      ["labo demo-groupes/hosts-prio.yaml", "cd /labo/projet/demo-groupes && ansible-inventory -i hosts-prio.yaml --host managed-node-1", "mon_groupe"],
      ["labo demo-groupes/hosts-enfant.yaml", "cd /labo/projet/demo-groupes && ansible-inventory -i hosts-enfant.yaml --host managed-node-1", "mon_groupe"],
      ["labo exercice web1", "cd /labo/projet/exercice && ansible-inventory -i parc.yaml --host web1", "host_vars"],
      ["labo exercice web2", "cd /labo/projet/exercice && ansible-inventory -i parc.yaml --host web2", "prod"],
      ["labo exercice bdd1", "cd /labo/projet/exercice && ansible-inventory -i parc.yaml --host bdd1", "bdd"],
    ];
    const nTel = tel.length;
    await Promise.all(tel.map(async ([nom, cmd, attendu]) => {
      const r = await executer(cmd, "/");
      let v = null; try { v = JSON.parse(r.sortie.slice(r.sortie.indexOf("{"))); } catch { /* sortie illisible */ }
      comparer(nom, "valeur (diapo)", ((v?.welcome_msg ?? v?.msg) ?? "").replace(/^from /, ""), attendu);
    }));
    {
      const r = await executer("cd /labo/projet/exercice && ansible-playbook -i parc.yaml qui-gagne.yml 2>&1 | grep -c '\"msg\": \"play\"'", "/");
      comparer("labo exercice qui-gagne.yml", "nombre d'hôtes qui voient « play »", r.sortie.trim(), "4");
    }

    // Un cycle de groupes : Ansible refuse l'inventaire.
    {
      const e = { ...vide(), parents: { ...vide().parents, web: "prod", prod: "web" }, membres: ["web"] };
      const id = `p${++compteur}`; ecrireProjet({ ...e, parents: { bdd: "prod", nouveaux: "all", prod: "all", web: "prod" } }, path.join(dossierTmp, id));
      fs.writeFileSync(path.join(dossierTmp, id, "inv/hosts.yaml"), jsonYaml({ all: { children: { prod: { children: { web: { hosts: { [HOTE]: null } } } }, web: { children: { prod: {} } } } } }));
      const r = await executer(`ansible-inventory -i inv/hosts.yaml --host ${HOTE}`, `/w/${id}`);
      comparaisons++;
      if (!/Unable to parse|No inventory was parsed/.test(r.sortie)) signaler("cycle de groupes", "Ansible devait refuser l'inventaire");
      comparaisons++;
      if (!simuler(e).erreur) signaler("cycle de groupes", "le simulateur devait refuser le cycle");
    }

    // Les cas : base (inventaire, playbook), puis épluchage.
    const taches = [], resultats = new Array(cas.length);
    cas.forEach((c, n) => taches.push(async () => {
      const sim = simuler(c.e), simInv = simuler(c.e, "inventaire");
      const lignes = [];
      const verif = (quoi, vrai, attendu) => { comparaisons++; if (vrai !== attendu) { ecarts++; lignes.push(`ÉCART  ${c.nom}\n         ${quoi} : Ansible ${JSON.stringify(vrai)} ≠ simulateur ${JSON.stringify(attendu)}`); } };
      const annonce = (quoi, annonce, simule) => { comparaisons++; if (annonce !== simule) { ecarts++; lignes.push(`ÉCART  ${c.nom}\n         ${quoi} : attendu ${JSON.stringify(annonce)} ≠ simulateur ${JSON.stringify(simule)}`); } };
      if (c.attendu !== undefined) annonce("valeur annoncée par la diapo", c.attendu, sim.valeur);
      if (c.fort) annonce("la source la plus forte de la paire gagne", { "defaults": SOURCES.defaults.nom, all: SOURCES.all.nom, "host_vars": SOURCES.host.nom, play: SOURCES.play.nom, "vars/ du rôle": SOURCES.rolevars.nom, bloc: SOURCES.bloc.nom, "tâche": SOURCES.tache.nom, set_fact: SOURCES.setfact.nom, "-e": SOURCES.extra.nom, "group_vars/prod (profondeur 1)": "group_vars/prod", "group_vars/web (profondeur 2)": "group_vars/web" }[c.fort], sim.source?.nom);
      const extra = c.e.sources.includes("extra");
      const ri = await reel("inventaire", sansExtra(c.e));
      verif("inventaire (ansible-inventory --host)", ri.erreur ? `ERREUR ${ri.erreur.slice(0, 200)}` : ri.valeur, simInv.valeur);
      const rp = await reel("playbook", sansExtra(c.e), extra);
      verif("playbook (ansible-playbook)", rp.erreur ? `ERREUR ${rp.erreur.slice(0, 300)}` : rp.valeur, sim.valeur);
      // Épluchage : retirer la source qui gagne, puis la suivante… ; le gagnant doit être la suivante du classement.
      const classement = [...sim.classement].reverse();
      let courant = c.e;
      for (let j = 0; j < classement.length - 1; j++) {
        const retire = classement[j];
        courant = retire.groupe ? { ...courant, fichiers: courant.fichiers.filter(g => g !== retire.groupe) } : { ...courant, sources: courant.sources.filter(s => s !== retire.id) };
        const suivant = classement[j + 1];
        const vrai = await reel("playbook", sansExtra(courant), courant.sources.includes("extra"));
        verif(`épluchage : sans « ${classement.slice(0, j + 1).map(s => s.nom).join(" », « ")} », le gagnant`, vrai.erreur ? `ERREUR ${vrai.erreur.slice(0, 300)}` : vrai.valeur, suivant.valeur);
      }
      resultats[n] = { sim, lignes, etapes: classement.length };
    }));
    let affiche = 0;
    await enParallele(taches, 4, (f, t) => { if (f * 10 >= (affiche + 1) * t) { affiche++; process.stderr.write(`\r${f}/${t} cas`); } });
    process.stderr.write("\r                \r");
    cas.forEach((c, n) => {
      const r = resultats[n];
      for (const l of r.lignes) console.log(l);
      console.log(`${r.lignes.length ? "ÉCART " : "accord"} | ${c.nom.padEnd(52)} | ${r.sim.erreur ?? (r.sim.source ? `${r.sim.valeur} ← ${r.sim.source.nom} (${r.sim.classement.length} source${r.sim.classement.length > 1 ? "s" : ""})` : "indéfinie")}`);
    });
    const total = cas.length + nTel + 2;
    console.log(`\n${total} cas et ${comparaisons} comparaisons avec ${version}, ${python} : ${ecarts === 0 ? "aucun écart" : ecarts + " écart(s)"}.`);
    nettoyer();
    if (process.argv.includes("--supprimer-image")) for (const i of [IMAGE, "artefact-ansible-base"]) docker(["image", "rm", i]);
    process.exit(ecarts ? 1 : 0);
  } catch (err) { nettoyer(); throw err; }
})().catch(e => { console.error("ÉCHEC :", e.message); process.exit(2); });
