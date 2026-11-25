#!/usr/bin/env node
// verifier-bash.js — confronte le simulateur au vrai Bash.
// Pour chaque cas (une ligne, un jeu de variables, des fichiers), le script crée dans un conteneur debian:13-slim
// (Bash 5.2.37, celui du cours) un répertoire /home/ada/labo avec les mêmes fichiers et dossiers, définit les mêmes
// variables, puis fait exécuter la ligne par le vrai Bash en remplaçant le nom de la commande par une fonction `argv` qui
// écrit chaque argument suivi d'un octet nul ; la sortie est relue octet par octet (hexadécimal) et comparée à l'argv du
// simulateur. Un cas que le simulateur déclare hors de sa portée (« Limitation du simulateur ») n'est PAS exécuté : on
// vérifie seulement qu'il l'affiche. Un cas que le simulateur déclare refusé par Bash (guillemet non fermé…) doit l'être
// aussi par le vrai Bash : aucun argument imprimé, code de retour non nul.
// Les cas : une liste écrite à la main (chaque règle, chaque combinaison de guillemets, les diapos, les recettes), puis des
// lignes tirées au hasard, avec une graine, depuis la grammaire du sous-ensemble ; enfin une liste de lignes hors
// sous-ensemble, dont le simulateur doit déclarer chacune hors de portée (elles ne sont jamais exécutées).
// SÛRETÉ : le générateur n'engendre que des arguments (jamais de nom de commande, de redirection, de tube ni de
// substitution de commande autre que $(echo …)) ; de plus, seule une ligne que l'analyseur du simulateur a acceptée
// (il refuse tout opérateur) atteint Bash ; enfin le conteneur n'a pas de réseau, un système de fichiers en lecture seule
// et ne touche qu'à des répertoires jetables.
//
// Prérequis : Docker, Node.js (l'image debian:13-slim, déjà présente ou tirée une fois).
//   node shell/artefacts/expansions-bash/verifier-bash.js [--graine N] [--hasard N] [--liste]
// Il ne touche qu'à ses conteneurs (artefact-eb-*) ; aucun prune.
const { spawnSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const sim = require("./expansions-bash.js");

const IMAGE = "debian:13-slim";
const arg = (nom, defaut) => { const i = process.argv.indexOf(nom); return i < 0 ? defaut : +process.argv[i + 1]; };
const GRAINE = arg("--graine", 20261125), N_HASARD = arg("--hasard", 6000);
const LISTE = process.argv.includes("--liste");
const docker = (args, options = {}) => spawnSync("docker", args, { encoding: "utf8", maxBuffer: 1 << 29, ...options });

// ---------- Les entrées par défaut ----------
const VARS = [["p", "Ada Lovelace"], ["vide", ""], ["motif", "*.txt"], ["nom", "Grace     Hopper"], ["dossier", "Mon dossier important"],
  ["fichier", "rapport"], ["ext", "txt"], ["chemin", "/usr/local/bin"], ["q", "a?b"], ["w", " lead trail "], ["dol", "$p"], ["til", "~"],
  ["sq", "it's"], ["dq", "say \"hi\""], ["br", "{x,y}"], ["etoile", "*"], ["sp", "  "], ["src", "src"]];
const FICHIERS = ["ada.txt", "grace.txt", "hedy.txt", "notes.md", ".cache", "Mon fichier.txt", "a b.md", "a*b", "mes documents/rapport.txt",
  "mes documents/notes de cours.txt", "vide/", "src/main.c", "src/util.c", "src/.hidden", "src/sub/deep.txt"];
const TROIS = ["ada.txt", "grace.txt", "hedy.txt"];

// ---------- Les cas écrits à la main ----------
// Chaque ligne est jouée avec les variables VARS et les fichiers FICHIERS, sauf indication (`avec`).
const CAS_TEXTE = fs.readFileSync(path.join(__dirname, "cas-bash.txt"), "utf8");
const section = nom => CAS_TEXTE.split(/^== /m).slice(1).find(x => x.startsWith(nom + "\n")).slice(nom.length + 1);
const MAIN = section("main");
// Cas qui demandent des jeux de variables ou de fichiers particuliers.
const AVEC = [
  { ligne: "printf '[%s]\\n' *.txt \"*.txt\"", fichiers: [] },
  { ligne: "printf '[%s]\\n' * .* ?", fichiers: [] },
  { ligne: "printf '[%s]\\n' $p \"$p\"", variables: [] },
  { ligne: "printf '[%s]\\n' $p \"$p\"", variables: [["p", "  "]] },
  { ligne: "printf '[%s]\\n' $p \"$p\"", variables: [["p", ""]] },
  { ligne: "printf '[%s]\\n' $p", variables: [["p", "a  b\tc"]] },
  { ligne: "printf '[%s]\\n' $p", variables: [["p", "-n"]] },
  { ligne: "printf '[%s]\\n' $p", variables: [["p", "a\\b"]] },
  { ligne: "printf '[%s]\\n' $p*", variables: [["p", "a\\b"]], fichiers: ["a\\b.txt", "ab.txt"] },
  { ligne: "printf '[%s]\\n' $p", variables: [["p", "[ab]"]], fichiers: ["a", "b"] },
  { ligne: "printf '[%s]\\n' *", fichiers: ["Zèbre.txt", "apple", "Banana", "10", "2", "_x", "-n", "~", "é", "A.txt", "a.TXT"] },
  { ligne: "printf '[%s]\\n' *.txt", fichiers: ["a.txt", "A.TXT", "b.Txt", "txt", ".txt"] },
  { ligne: "printf '[%s]\\n' * */ */*", fichiers: ["a/b", "a-b/c", "a.b/d", "a/c/d", "z"] },
  { ligne: "printf '[%s]\\n' $motif", variables: [["motif", "*.txt"]], fichiers: ["x y.txt", "z.txt"] },
  { ligne: "printf '[%s]\\n' $motif", variables: [["motif", "*.txt *.md"]], fichiers: ["a.txt", "b.md", "c.sh"] },
  { ligne: "printf '[%s]\\n' \"$motif\" '$motif'", variables: [["motif", "*.txt *.md"]], fichiers: ["a.txt", "b.md", "c.sh"] },
  { ligne: "printf '[%s]\\n' *", fichiers: ["a", "a/b"] },
  { ligne: "printf '[%s]\\n' */*", fichiers: ["a/b", "a"] },
  { ligne: "printf '[%s]\\n' d/*", fichiers: ["d/"] },
  { ligne: "printf '[%s]\\n' d/*/", fichiers: ["d/e/", "d/f"] },
  { ligne: "printf '[%s]\\n' $(echo *)", fichiers: ["a b", "c"] },
  { ligne: "printf '[%s]\\n' \"$(echo *)\"", fichiers: ["a b", "c"] },
  { ligne: "printf '[%s]\\n' $(echo $p)", variables: [["p", "-n x"]] },
  { ligne: "printf '[%s]\\n' $(echo \"$p\")", variables: [["p", "-n"]] },
  { ligne: "printf '[%s]\\n' $(echo \"$p\")", variables: [["p", "x -n"]] },
  { ligne: "printf '[%s]\\n' \"$HOME\" $HOME ${HOME}x $HOME/x ~/x \"$PWD\" $PWD" },
  { ligne: "printf '[%s]\\n' \"$p\" ", variables: [["p", "a\nb"]] },
];

// ---------- Les lignes hors sous-ensemble : toutes doivent être déclarées hors de portée ----------
const HORS = section("hors");

// ---------- Générateur pseudo-aléatoire à graine (mulberry32) ----------
function hasard(graine) {
  let a = graine >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
const rnd = hasard(GRAINE);
const choix = l => l[Math.floor(rnd() * l.length)];
const entier = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const NOMS = [...VARS.map(v => v[0]), "inconnue", "autre", "p", "p", "motif", "nom", "vide"];
const LIT = ["a", "b", "x", "ab", "abc", "txt", ".txt", ".", "-", "_", "=", ":", ",", "1", "2", "é", "%", "@", "+", "^", "e", "d", ".md", "ada", "src", "c"];
const GLOBS = ["*", "?", "*.txt", "?.txt", "a*", "*a*", ".*", "*.md", "??", "*b", "g*", "*.*", "?*", "src/*", "*/*", "*/", "src/*.c", "mes*/*", "vide/*", "./*", "src/.*", "*/.*", "d?*"];
const nom = () => choix(NOMS);
const sansEspace = s => s.replace(/ /g, "");
let dansCommande = 0;   // > 0 : on écrit l'intérieur d'un $(echo …), où le générateur n'imbrique pas de substitution
function argsEcho(prof) {   // arguments simples d'un $(echo …)
  const n = entier(0, 3), mots = [];
  dansCommande++;
  for (let i = 0; i < n; i++) mots.push(piece(prof + 2, "nu", false) + (rnd() < 0.4 ? piece(prof + 2, "nu", false) : ""));
  dansCommande--;
  return mots.join(choix([" ", " ", "  "]));
}
function contenuDq(prof) {
  const n = entier(0, 4); let s = "";
  for (let i = 0; i < n; i++) {
    const r = rnd();
    if (r < 0.25) s += choix(LIT);
    else if (r < 0.35) s += choix([" ", "  "]);
    else if (r < 0.55) s += "$" + nom();
    else if (r < 0.62) s += "${" + nom() + "}";
    else if (r < 0.68) s += choix(["\\$", "\\\\", "\\\"", "\\q", "\\*"]);
    else if (r < 0.74) s += choix(["*", "?", "{a,b}", "{1..3}", "~", "'", "[", "!", "$", "/"]);
    else if (r < 0.80) s += "$" + nom() + choix(LIT);
    else if (r < 0.86 && prof < 2 && !dansCommande) s += "$(echo " + argsEcho(prof) + ")";
    else s += choix(LIT);
  }
  return s;
}
function contenuSq() {
  const n = entier(0, 3); let s = "";
  for (let i = 0; i < n; i++) s += choix(LIT.concat([" ", "$p", "*", "{a,b}", "\"", "\\", "~", "?", "$(echo a)", "${p}"].filter(x => !(dansCommande && x.includes("(")))));
  return s;
}
// Une pièce de mot. `debut` : première pièce du mot (le tilde y a un sens). `ctx` : toujours « nu » ici.
function piece(prof, ctx, debut) {
  const r = rnd();
  if (r < 0.14) return choix(LIT);
  if (r < 0.22) return choix(GLOBS);
  if (r < 0.34) return "$" + nom();
  if (r < 0.38) return "${" + nom() + "}";
  if (r < 0.41) return "$" + nom() + choix(["_x", "1", "a", "txt", "_"]);
  if (r < 0.49) return '"' + contenuDq(prof) + '"';
  if (r < 0.53) return "'" + contenuSq() + "'";
  if (r < 0.58) return "\\" + choix(["*", "?", "$", "\\", "'", '"', " ", "a", "{", "}", ",", "~", ".", "/"]);
  if (r < 0.63 && debut) return choix(["~", "~", "~/x", "~/"]);
  if (r < 0.68 && !dansCommande) return "$(echo " + argsEcho(prof) + ")";
  if (r < 0.70) return "$'" + choix(["a\\tb", "x", "\\n", "it\\'s", "\\\\", "a b", "*", "\\\"", "$p", "{a,b}"]) + "'";
  if (prof < 3) {
    if (r < 0.80) {
      const k = entier(2, 3), alts = [];
      for (let i = 0; i < k; i++) alts.push(rnd() < 0.25 ? "" : piece(prof + 1, "nu", false) + (rnd() < 0.3 ? piece(prof + 1, "nu", false) : ""));
      return "{" + alts.join(",") + "}";
    }
    if (r < 0.84) return choix(["{1..3}", "{3..1}", "{-1..1}", "{0..2}", "{5..5}", "{1..4}"]);
    if (r < 0.86) return choix(["{", "}", "{}", "{a}", "{,", ",}", "{a,b", "a}"]);
  }
  return choix(LIT);
}
function mot() {
  const n = entier(1, 4); let s = "";
  for (let i = 0; i < n; i++) s += piece(0, "nu", i === 0);
  return s;
}
function ligneAleatoire() {
  const n = entier(1, 4), mots = [];
  for (let i = 0; i < n; i++) mots.push(mot());
  return "printf '[%s]\\n' " + mots.join(choix([" ", " ", " ", "  "]));
}
const VALEURS = ["Ada Lovelace", "", " ", "  a  b  ", "*.txt", "*", "?", "a?", "*.t*", "{x,y}", "$p", "~", "~/x", "a'b", "a\"b", "a\\b", "-n", "a\tb", "x y z", "a/b",
  "/home/ada", "é", "[ab]", ".*", "src/*", "mes documents", "src/*.c", "a b*", "A.txt", "txt", "ada", "*/*", "x  ", "  x", "a*b", "a,b", "{a,b}", "'", "\"", "$", "\\", "-e", "$(echo a)"];
const FICHIERS_POOL = ["ada.txt", "grace.txt", "hedy.txt", "notes.md", ".cache", ".env", "Mon fichier.txt", "a b.md", "a*b", "a", "b", "ab", "abc", "a.b", "A.txt", "a.TXT",
  "é.txt", "-x", "?", "x~", "~", "c", "d", "e.md", "x y", "src/main.c", "src/util.c", "src/.hidden", "src/sub/deep.txt", "mes documents/rapport.txt", "mes documents/n.txt", "vide/", "d/e/f", "d-x/g", "e/"];
function jeuAleatoire() {
  const variables = rnd() < 0.5 ? VARS : (() => {
    const n = entier(2, 8), vu = new Set(), liste = [];
    for (let i = 0; i < n; i++) { const k = choix(NOMS.filter(x => x !== "inconnue" && x !== "autre")); if (vu.has(k)) continue; vu.add(k); liste.push([k, choix(VALEURS)]); }
    return liste;
  })();
  let fichiers = rnd() < 0.4 ? FICHIERS : rnd() < 0.25 ? TROIS : (() => { const n = entier(0, 9); return Array.from({ length: n }, () => choix(FICHIERS_POOL)); })();
  return { variables, fichiers };
}

// ---------- Les cas ----------
const cas = [];
const vus = new Set();
const ajouter = (c) => {
  const cle = JSON.stringify([c.ligne, c.variables, c.fichiers]);
  if (vus.has(cle)) return;
  vus.add(cle); cas.push(c);
};
for (const ligne of MAIN.split("\n").filter(l => l.trim() !== "")) ajouter({ ligne, variables: VARS, fichiers: FICHIERS, groupe: "liste" });
for (const ligne of MAIN.split("\n").filter(l => l.trim() !== "")) ajouter({ ligne, variables: VARS, fichiers: TROIS, groupe: "liste" });
for (const a of AVEC) ajouter({ ligne: a.ligne, variables: a.variables ?? VARS, fichiers: a.fichiers ?? FICHIERS, groupe: "liste" });
// Les lignes des diapos et des recettes (exportées par le simulateur).
for (const r of sim.CAS_DES_RECETTES) ajouter({ ...r, groupe: "recettes" });
const nListe = cas.length;
for (let i = 0; i < N_HASARD; i++) { const j = jeuAleatoire(); ajouter({ ligne: ligneAleatoire(), ...j, groupe: "hasard" }); }

// ---------- Exécution dans le vrai Bash ----------
const sq = s => "'" + s.replace(/'/g, "'\\''") + "'";
function reel(lot) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-bash-"));
  lot.forEach((c, i) => {
    const reste = c.ligne.slice(/^\s*\S+/.exec(c.ligne)[0].length);   // tout ce qui suit le nom de la commande
    const script = c.variables.map(([k, v]) => `${k}=${sq(v)}\n`).join("")
      + "argv() { local a; for a in \"$@\"; do printf '%s\\0' \"$a\"; done; }\n" + "argv" + reste + "\n";
    fs.writeFileSync(`${d}/${i}.sh`, script);
    fs.writeFileSync(`${d}/${i}.f`, c.fichiersReels.join("\0") + (c.fichiersReels.length ? "\0" : ""));
  });
  // Pour chaque cas : un dossier neuf ; les dossiers (chemin terminé par /) d'abord, puis les fichiers ; l'env est minimal.
  const pilote = `cd /
for i in $(seq 0 ${lot.length - 1}); do
  rm -rf /home/ada/labo; mkdir -p /home/ada/labo; cd /home/ada/labo
  while IFS= read -r -d '' f; do case "$f" in */) mkdir -p -- "./$f";; *) mkdir -p -- "$(dirname -- "./$f")"; : > "./$f";; esac; done < /cas/$i.f
  env -i HOME=/home/ada PATH=/usr/bin:/bin LC_ALL=C.UTF-8 timeout 5 bash --noprofile --norc /cas/$i.sh >/tmp/o 2>/tmp/e; rc=$?
  printf '%s\\t%s\\t%s\\t%s\\n' "$i" "$rc" "$(od -An -v -tx1 /tmp/o | tr -d ' \\n')" "$(head -c 400 /tmp/e | tr '\\n\\t' '  ')"
  cd /
done`;
  const nom = `artefact-eb-${process.pid}`;
  const r = docker(["run", "--rm", "--name", nom, "--network", "none", "--read-only", "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
    "--pids-limit", "256", "--memory", "512m", "--tmpfs", "/home:exec", "--tmpfs", "/tmp", "-v", `${d}:/cas:ro`, IMAGE, "bash", "-c", pilote]);
  docker(["rm", "-f", nom]);
  fs.rmSync(d, { recursive: true });
  if (r.status !== 0) throw new Error("le conteneur a échoué :\n" + r.stderr);
  const sortie = new Map();
  for (const ligne of r.stdout.split("\n").filter(Boolean)) {
    const [i, rc, hex, err] = ligne.split("\t");
    const octets = Buffer.from(hex ?? "", "hex");
    const args = octets.length ? octets.toString("utf8").split("\0").slice(0, -1) : [];
    sortie.set(+i, { rc: +rc, args, err, valide: Buffer.from(args.join("\0") + (args.length ? "\0" : ""), "utf8").equals(octets) });
  }
  return sortie;
}
const version = () => docker(["run", "--rm", "--name", `artefact-eb-v-${process.pid}`, "--network", "none", IMAGE, "bash", "-c", "bash --version | head -1"]).stdout.trim();

// ---------- Comparaison ----------
const aFaire = [];    // les cas à exécuter pour de vrai
const horsPortee = [], refuses = [];
for (const c of cas) {
  c.sim = sim.simuler({ ligne: c.ligne, variables: c.variables, fichiers: c.fichiers });
  c.fichiersReels = c.sim.fichiers;
  if (c.sim.limites.length) horsPortee.push(c);
  else if (c.sim.erreur) { refuses.push(c); aFaire.push(c); }
  else aFaire.push(c);
}
const t0 = Date.now();
const sorties = new Map();
const TAILLE = 1500;
for (let k = 0; k < aFaire.length; k += TAILLE) {
  const lot = aFaire.slice(k, k + TAILLE);
  const r = reel(lot);
  lot.forEach((c, i) => sorties.set(c, r.get(i)));
}
const montrer = a => JSON.stringify(a);
let ecarts = 0, accords = 0;
const parGroupe = {};
for (const c of aFaire) {
  const o = sorties.get(c);
  parGroupe[c.groupe] = (parGroupe[c.groupe] ?? 0) + 1;
  let probleme = null;
  if (!o) probleme = "pas de sortie du conteneur";
  else if (c.sim.erreur) { if (o.args.length || o.rc === 0) probleme = `Bash accepte la ligne (rc ${o.rc}, ${montrer(o.args)}), le simulateur la déclare refusée (${c.sim.erreur})`; }
  else if (o.rc !== 0) probleme = `Bash échoue (rc ${o.rc} : ${o.err}) ; le simulateur calcule ${montrer(c.sim.argv)}`;
  else if (!o.valide) probleme = "sortie illisible (octets non UTF-8)";
  else if (montrer(o.args) !== montrer(c.sim.argv)) probleme = `Bash : ${montrer(o.args)}\n  simulateur : ${montrer(c.sim.argv)}`;
  if (probleme) {
    ecarts++;
    console.log(`ÉCART [${c.groupe}] ${c.ligne}\n  variables ${montrer(c.variables.filter(([k]) => new RegExp("\\$\\{?" + k + "\\b").test(c.ligne) || true).map(([k, v]) => `${k}=${v}`)).slice(0, 400)}\n  fichiers ${montrer(c.fichiersReels)}\n  ${probleme}`);
  } else { accords++; if (LISTE && c.groupe !== "hasard") console.log(`accord  ${c.ligne}  ->  ${montrer(c.sim.argv ?? "(refusée)")}`); }
}
const limitesDistinctes = new Set(horsPortee.map(c => c.sim.limites[0].split(" : ")[0].slice(0, 60)));
const limitesHasard = horsPortee.filter(c => c.groupe === "hasard").length;
if (process.argv.includes("--limites")) {
  const n = new Map();
  for (const c of horsPortee.filter(c => c.groupe === "hasard")) n.set(c.sim.limites[0].slice(0, 90), (n.get(c.sim.limites[0].slice(0, 90)) ?? 0) + 1);
  for (const [m, k] of [...n].sort((a, b) => b[1] - a[1])) console.log(`${String(k).padStart(5)} limitation du hasard : ${m}`);
}

// Les lignes hors sous-ensemble : toutes doivent être déclarées hors de portée (jamais exécutées).
const hors = [...new Set(HORS.split("\n").filter(l => l.trim() !== ""))];
let horsEcarts = 0;
const messages = new Set();
for (const ligne of hors) {
  const r = sim.simuler({ ligne, variables: VARS, fichiers: FICHIERS });
  if (r.limites.length) messages.add(r.limites[0]);
  else if (r.erreur) { horsEcarts++; console.log(`HORS-SOUS-ENSEMBLE : « ${ligne} » est déclarée erreur de syntaxe (${r.erreur}) au lieu d'une limitation`); }
  else { horsEcarts++; console.log(`HORS-SOUS-ENSEMBLE : « ${ligne} » n'est PAS déclarée hors de portée : argv ${montrer(r.argv)}`); }
}

const v = version();
console.log(`\n${cas.length} cas (${nListe} écrits à la main et des recettes, ${cas.length - nListe} tirés au hasard, graine ${GRAINE}) : ${aFaire.length} exécutés dans le vrai Bash (${accords} d'accord, ${ecarts} écarts),`
  + ` dont ${refuses.length} lignes que Bash refuse comme le simulateur ; ${horsPortee.length} déclarés hors de portée sans être exécutés (dont ${limitesHasard} du hasard ; ${limitesDistinctes.size} limitations différentes).`
  + `\n${hors.length} lignes hors sous-ensemble : ${hors.length - horsEcarts} déclarées hors de portée (${messages.size} messages différents), ${horsEcarts} écarts.`
  + `\nOutil réel : ${v}, ${IMAGE} (${((Date.now() - t0) / 1000).toFixed(0)} s).`);
process.exit(ecarts || horsEcarts ? 1 : 0);
