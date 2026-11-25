#!/usr/bin/env node
// verifier-analyseurs.js — confronte le simulateur aux vrais analyseurs YAML.
// Pour chaque cas, le texte est écrit dans un document « k: <texte> » (ou un petit document) et lu par :
//   - PyYAML (yaml.safe_load), qui suit YAML 1.1, comparé au simulateur en mode 1.1 ;
//   - ruamel.yaml (YAML(typ="safe", pure=True), YAML 1.2 par défaut), comparé au simulateur en mode 1.2 ;
// tous deux paquets Debian 13 (python3-yaml, python3-ruamel.yaml), dans un conteneur debian:13-slim.
// Pour chaque version, on compare : le type et la valeur (arbre complet), le repr Python, le JSON écrit par json.dumps
// (et son échec, avec la classe d'exception et le message), ou l'exception de l'analyseur (classe et message).
// Les cas : une liste qui couvre chaque règle des deux schémas (une centaine de scalaires, des documents), puis des
// scalaires et des documents tirés au hasard, avec une graine, autour des cas limites (signes, soulignés, deux-points,
// exposants, préfixes 0x 0b 0o, casse des mots, dates impossibles, guillemets, étiquettes, caractères d'indicateur).
// Un cas que le simulateur déclare hors de sa portée (« Limitation du simulateur ») n'est pas comparé : on vérifie
// seulement qu'il l'affiche, et on en donne le nombre.
//
// Prérequis : Docker, Node.js. L'image artefact-ty-analyseurs (debian:13-slim + les deux paquets) est construite au
// premier lancement ; derrière un proxy HTTPS qui réécrit TLS, HTTPS_PROXY et le certificat /root/.ccr/ca-bundle.crt
// (ou TPTEST_CA) sont passés à `docker build --network host`.
//   node edition-formats/artefacts/typage-yaml/verifier-analyseurs.js [--graine N] [--hasard N] [--liste]
// Il ne touche qu'à son conteneur (artefact-ty-*) et à son image (artefact-ty-analyseurs) ; aucun prune.
const { spawnSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const sim = require("./typage-yaml.js");

const IMAGE = "artefact-ty-analyseurs";
const arg = (nom, defaut) => { const i = process.argv.indexOf(nom); return i < 0 ? defaut : +process.argv[i + 1]; };
const GRAINE = arg("--graine", 20261125), N_HASARD = arg("--hasard", 4000);
const LISTE = process.argv.includes("--liste");
const docker = (args, options = {}) => spawnSync("docker", args, { encoding: "utf8", maxBuffer: 1 << 28, ...options });

// ---------- L'image : debian:13-slim + python3-yaml + python3-ruamel.yaml ----------
function image() {
  if (docker(["image", "inspect", IMAGE]).status === 0) return;
  const dossier = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-analyseurs-"));
  const ca = [process.env.TPTEST_CA, "/root/.ccr/ca-bundle.crt"].find(c => c && fs.existsSync(c));
  const proxy = process.env.HTTPS_PROXY || "";
  const reseau = ca && proxy;
  if (reseau) fs.copyFileSync(ca, path.join(dossier, "ca-hote.crt")); else fs.writeFileSync(path.join(dossier, "ca-hote.crt"), "");
  fs.writeFileSync(path.join(dossier, "Dockerfile"), `FROM debian:13-slim
COPY ca-hote.crt /run/ca-hote.crt
ARG HTTPS_PROXY
RUN if [ -n "$HTTPS_PROXY" ]; then \\
      sed -i "s|http://deb.debian.org|https://deb.debian.org|g" /etc/apt/sources.list.d/debian.sources \\
      && printf 'Acquire::https::Proxy "%s";\\nAcquire::https::CAInfo "/run/ca-hote.crt";\\n' "$HTTPS_PROXY" > /etc/apt/apt.conf.d/99mandataire; fi \\
 && apt-get update -qq \\
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends python3 python3-yaml python3-ruamel.yaml ca-certificates > /dev/null \\
 && rm -f /etc/apt/apt.conf.d/99mandataire && rm -rf /var/lib/apt/lists/*
`);
  const r = docker(["build", "-q", "--network", reseau ? "host" : "default", ...(reseau ? ["--build-arg", `HTTPS_PROXY=${proxy}`] : []), "-t", IMAGE, dossier]);
  fs.rmSync(dossier, { recursive: true });
  if (r.status !== 0) throw new Error("docker build a échoué :\n" + r.stderr);
}

// ---------- Le programme Python exécuté dans le conteneur ----------
const PYTHON = String.raw`
import sys, json, datetime, warnings
import yaml
from ruamel.yaml import YAML
warnings.simplefilter("ignore")
# un YAML() neuf par lecture : un objet qui a échoué garde un état interne et fausserait la lecture suivante
def y12(texte): return YAML(typ="safe", pure=True).load(texte)
def arbre(v):
    if v is None: return ["null"]
    if isinstance(v, bool): return ["bool", v]
    if isinstance(v, int): return ["int", str(v)]
    if isinstance(v, float): return ["float", repr(v)]
    if isinstance(v, str): return ["str", v]
    if isinstance(v, datetime.datetime): return ["datetime", v.isoformat()]
    if isinstance(v, datetime.date): return ["date", v.isoformat()]
    if isinstance(v, list): return ["list", [arbre(x) for x in v]]
    if isinstance(v, dict): return ["dict", [[arbre(k), arbre(x)] for k, x in v.items()]]
    if isinstance(v, tuple): return ["tuple", [arbre(x) for x in v]]
    return ["autre", type(v).__name__]   # étiquette que le simulateur ne lit pas (!!binary, !!set…) : il doit la déclarer hors de portée
def erreur(e):
    return {"ok": False, "classe": type(e).__name__, "message": getattr(e, "problem", None) or str(e)}
def lire(charger, cas):
    try:
        v = charger(cas["doc"])
        if cas["mode"] == "scalaire": v = v["k"]
    except Exception as e:
        return erreur(e)
    r = {"ok": True, "arbre": arbre(v)}
    if not isinstance(v, (datetime.datetime,)) and not isinstance(v, (list, dict)): r["repr"] = repr(v)
    try: r["json"] = {"texte": json.dumps(v, ensure_ascii=False)}
    except Exception as e: r["json"] = {"erreur": {"classe": type(e).__name__, "message": str(e)}}
    return r
sortie = []
for cas in json.load(sys.stdin):
    sortie.append({"1.1": lire(yaml.safe_load, cas), "1.2": lire(y12, cas)})
json.dump(sortie, sys.stdout)
`;
function analyseursReels(cas) {
  const nom = `artefact-ty-${process.pid}`;
  const r = docker(["run", "--rm", "-i", "--name", nom, IMAGE, "python3", "-I", "-c", PYTHON], { input: JSON.stringify(cas) });
  docker(["rm", "-f", nom]);
  if (r.status !== 0) throw new Error("le conteneur a échoué :\n" + r.stderr);
  return JSON.parse(r.stdout);
}
const versions = () => {
  const r = docker(["run", "--rm", "--name", `artefact-ty-v-${process.pid}`, IMAGE, "sh", "-c",
    "dpkg-query -W -f '${Package} ${Version}\\n' python3-yaml python3-ruamel.yaml; python3 -c 'import yaml, ruamel.yaml, sys; print(sys.version.split()[0], yaml.__version__, ruamel.yaml.__version__)'"]);
  return r.stdout.trim().split("\n");
};

// ---------- Les cas ----------
const SCALAIRES = `
true false True TRUE False FALSE yes no Yes No YES NO on off On Off ON OFF y n Y N tRuE nO oN
null Null NULL ~ nUll NULl
42 +42 -42 0 00 000 007 0644 +0644 -0644 0_7 0_ 0o644 0O644 0o8 0o 0o_7 0o17 08 09 0b101 0B1 0b 0b_ 0b2 0x1F 0X1f 0x 0xG 0x_1 0xff_ff
1_000 1_0 _1 1__0 +1_0 1_ 12_34_56 -_ +_
22:22 1:30 1:30:15 -1:30 +1:30 1:60 1:5 0:0 0:30 1:2:3:4 190:20:30 1:30.5 :30 1: 1:_ 1_0:30
3.14 .5 5. -.5 +.5 -5. 1e3 1E3 1e+3 1e-3 1E-3 1.0e3 1.e3 .1e3 .1e+3 -.1e-3 e3 1e 1.5e3 1.5e+3 1.5E+3 1_0.5 1.5_0 3.14_15 1.10 1.2.3 1.0.0 0.5 00.5 -0 -0.0 0e0 1e400 1e-400 1_0e3 .
.inf .Inf .INF -.inf +.inf -.Inf inf Inf INF -inf .nan .NaN .NAN nan NaN .iNf .nAn .infx ._ ._5 .5_
123456789012345678901234567890 9007199254740993 -9007199254740993 0.1 0.30000000000000004 100000000000000000000.0 1e16 1e15 1e22 123456789.123456789 0.0001 0.00001
2026-11-25 2024-01-15 2024-02-29 2023-02-29 2024-1-5 2024-13-45 2024-02-30 2024-00-10 2024-12-00 0000-01-01 0001-01-01 9999-12-31 12345-01-01
2001-12-14t21:59:43.10-05:00 2001-12-14T21:59:43Z 2001-12-14T21:59 2026-11-25T10:00:00+01:00 2026-11-25T10:00:00+0100 2026-11-25T24:00:00 2026-11-25T10:60:00 2026-11-25T10:00:60 2026-11-25T1:02:03 2026-11-25t10:00:00.5Z 2026-11-25T10:00:00.
2026-11-25T10:00:00+99:00 2026-11-25T10:00:00-23:59 2026-11-25T10:00:00+5 2026-11-25T10:00:00+05:99 2026-11-25T10:00:00.1234567 21:59:43.10
web01 hello 1.2.3 1984 a-b -- ... --- <<  = value é 日本 a_b A1 0a 1a x1 .a
`.split(/\s+/).filter(Boolean);
const SPECIAUX = [
  "", " ", "   ", "# commentaire", "a # commentaire", "a#b", "a #", "''", '""', "'NO'", '"NO"', "'42'", '"42"', "'~'", '"2026-11-25"',
  "'0644'", "'1:30'", "'a''b'", '"a\\nb"', '"\\x41"', '"\\u00e9"', '"\\U0001F600"', '"é"', "'a\\nb'", '"\\q"', '"\\xZZ"', '"\\x4"', '"\\u00"', '"\\ud800"',
  '"\\U00110000"', '"tab\\there"', '"\\0"', '"\\ "', '"\\/"', '"\\N\\_\\L\\P"', '"unterminated', "'unterminated", '"a" b', "'a' b", '"a" #c', '"a"#c', "'a' # c",
  '"a" ', '"a":', '"a": b', "''''", '""""', "'\"'", '"\'"', '"a\\\\b"', '"a\\"b"',
  "  spaced  ", "a b", "a  b", "Hello, world", "a, b", "a: b", "a:", "a:b", "a:  b", "a :b", "a:\tb", "- a", "-a", "-", "- ", "? a", "?a", "?", ": a", ":a", ":", ",a", "a,b", "]", "}", "[a]", "{a}", "[", "{", "&a", "*a", "|", ">", "|-", ">+",
  "%a", "@a", "`a", "a%", "a@", "a`", "a\tb", "\ta", "a\t", "a \t", "a\u00a0b", "a\u0085b", "\u00e9\u00e8", "\u{1F600}",
  "!!str 42", "!!str NO", "!!str", "!!str ''", "!!str \"x\"", "!!int 42", "!!int 0644", "!!int 0o17", "!!int 0x1F", "!!int 0b11", "!!int 1:30", "!!int '42'", "!!int abc", "!!int", "!!int ''", "!!int -5", "!!int +-5",
  "!!int 1_000", "!!int 08", "!!int 1.5", "!!float 1", "!!float 1.5", "!!float inf", "!!float -inf", "!!float nan", "!!float .inf", "!!float 1:30", "!!float abc", "!!float", "!!float 1e3", "!!float 0x1F",
  "!!bool yes", "!!bool y", "!!bool n", "!!bool Y", "!!bool maybe", "!!bool true", "!!bool 1", "!!bool", "!!null ~", "!!null x", "!!null", "!!null ''",
  "!!timestamp 2001-12-14", "!!binary x", "!!seq x", "!!map x", "!!foo bar", "!foo bar", "! 42", "!!int42", "!!str #c", "!!str  a  b",
  "'a' 'b'", '"a" "b"', "'a' [", "'a' ,", "'a' &x", "'a' - b",
  "[a]", "{a: b}", "'a", "a'b", 'a"b', "a 'b'", '"a"b', "[a, b", "&x a", "*x",
];
// Des documents qui couvrent les clés typées, les listes plates, les doublons, les commentaires.
const DOCUMENTS = [
  ...sim.DOCUMENTS.map(d => d[1]),
  "", "---\n", "# rien\n", "a: 1\n", "---\na: 1\nb: 2\n", "a: 1\na: 2\n", "yes: 1\nNo: 2\n", "yes: 1\nyes: 2\n", "1: a\n1.0: b\n", "true: a\n1: b\n", "true: a\ntrue: b\n", "1: a\n1: b\n", "~: a\nnull: b\n",
  "80: http\n443: https\n", "1.5: x\n.inf: y\n", "2026-11-25: jour\n", "2026-13-45: x\n", "a: 2026-13-45\n", "k: [1, 2, 3]\n", "k: [a, b,]\n", "k: []\n", "k: [ ]\n", "k: [a,,b]\n", "k: [,a]\n", "k: [22:22]\n", "k: [a:b, c]\n", "k: ['a', \"b\", c]\n",
  "k: [yes, no]\n", "k: [0644, 0o644]\n", "k: [1e3, 1.5e+3, .inf, ~, null, '']\n", "k: [2026-11-25]\n", "k: [a, b] # c\n", "k: [a, b] x\n", "k: [a, [b]]\n", "k: [a\n", "k:\n  - a\n  - b\n", "k:\n- a\n- b\n", "k:\n  - yes\n  - 0644\n  - '22:22'\n", "k:\n  -\n  - a\n", "k:\n  - a\n    - b\n", "k:\n  - a\n   - b\n",
  "k:\n  - a: b\n", "k:\n  - [a]\n", "k:\n  - - a\n", "k:\n", "k:\nj: 1\n", "k: # c\nj: 1\n", "k:\n  # c\n  - a\n", "k: v\n  l2\n", "k:\n  j: 1\n", "- a\n- b\n", "a\n", "a: 1\nb\n", "a: 1\n b: 2\n", "a: 1\n\n\nb: 2\n", "a: 1 # c\nb: 2 # d\n",
  "a b: 1\n", "a  b: 1\n", "a : 1\n", "a:1\n", "a:\t1\n", "'a': 1\n", "\"a\": 1\n", "<<: x\n", "=: x\n", "a: =\n", "a: <<\n", "%YAML 1.1\n---\na: no\n", "---\na: 1\n---\nb: 2\n", "a: 1\n...\n", "--- x\n", "--- # c\na: 1\n", "...\n", "?: 1\n", "-a: 1\n", ":a: 1\n", ",a: 1\n",
  "a: &x 1\nb: *x\n", "a: |\n  x\n", "a: >\n  x\n", "a: {b: 1}\n", "a: !!str 1\n", "a: !!int 0644\nb: !!bool y\n", "a: 1\r\nb: 2\r\n",
  "pays: [FR, NO, SE]\nactif: yes\nmode: 0644\n", "n: 0123\nv: 1.10\nd: 2024-01-15\nh: 7:30\n", "ports:\n  - 80:80\n  - 22:22\n  - '22:22'\n", "a: 1\nyes: 2\nb: [on, off]\n",
];
const BASES = [...SCALAIRES, ...SPECIAUX.filter(x => typeof x === "string")];

// Générateur pseudo-aléatoire à graine (mulberry32).
function hasard(graine) {
  let a = graine >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
const rnd = hasard(GRAINE);
const choix = liste => liste[Math.floor(rnd() * liste.length)];
const ALPHABET = [..."0123456789", ..."0123456789", ..."+-_:.", ..."eExXbBoO", ..."aAfFnNyY", " ", "#", "'", '"', "\\", "~", "!", ",", "[", "]", ":", "-", "."];
const MOTS = ["yes", "no", "on", "off", "true", "false", "null", "~", ".inf", ".nan", "NO", "Y", "n", "T", "Off", "NULL", "0x", "0b", "0o", "e", "E", "T", "Z", "t", "2024", "2026", "11", "02", "29", "30", "13", "00", "!!int ", "!!str ", "!!float ", "!!bool ", "!!null "];
const FRAGMENTS = [...MOTS, ..."0123456789".split(""), "+", "-", "_", ":", ".", "e", "E", "x", "b", "o", "-", "T", " ", ":", ".", "5", "1", "0", "7", "8", "9"];
function aleatoire() {
  const forme = rnd();
  let s = "";
  if (forme < 0.45) { const n = 1 + Math.floor(rnd() * 6); for (let i = 0; i < n; i++) s += choix(FRAGMENTS); }
  else if (forme < 0.85) {
    s = choix(BASES);
    const n = 1 + Math.floor(rnd() * 3);
    for (let k = 0; k < n; k++) {
      const p = Math.floor(rnd() * (s.length + 1)), m = rnd();
      if (m < 0.4) s = s.slice(0, p) + choix(ALPHABET) + s.slice(p);
      else if (m < 0.7) s = s.slice(0, p) + s.slice(p + 1);
      else s = s.slice(0, p) + choix(ALPHABET) + s.slice(p + 1);
    }
  } else { const base = rnd() < 0.5 ? choix(BASES) : choix(FRAGMENTS); const q = choix(["'", '"', "", "!!str ", "!!int ", "!!float ", "!!bool "]); s = q + base + (q === "'" || q === '"' ? q : ""); }
  if (rnd() < 0.05) s += choix([" # c", "  ", " #", "#"]);
  return s;
}
function documentAleatoire() {
  const cles = ["a", "k", "yes", "NO", "80", "1.5", "~", "2026-11-25", "on", "y", "true", "0644", "0o17", "null", ".inf", "1e3", "22:22", "v"];
  const lignes = [];
  if (rnd() < 0.3) lignes.push("---");
  const n = 1 + Math.floor(rnd() * 5);
  for (let i = 0; i < n; i++) {
    const cle = rnd() < 0.7 ? choix(cles) : aleatoire().replace(/[:\n]/g, "x") || "z";
    const f = rnd();
    const val = () => rnd() < 0.5 ? choix(BASES.filter(b => !/[,\[\]{}#:]/.test(b))) : aleatoire().replace(/[,\[\]{}]/g, "x");
    if (f < 0.55) lignes.push(`${cle}: ${val()}`);
    else if (f < 0.75) lignes.push(`${cle}: [${Array.from({ length: Math.floor(rnd() * 4) }, val).join(", ")}]`);
    else if (f < 0.9) { lignes.push(`${cle}:`); for (let j = 0, m = 1 + Math.floor(rnd() * 3); j < m; j++) lignes.push(`${choix(["  ", "", "    "])}- ${val()}`); }
    else lignes.push(rnd() < 0.5 ? `# ${val()}` : `${cle}: ${val()} # c`);
  }
  return lignes.join("\n") + "\n";
}

const cas = [];
const vus = new Set();
const ajouter = (mode, texte, groupe) => { const cle = mode + "\0" + texte; if (vus.has(cle)) return; vus.add(cle); cas.push({ mode, texte, doc: mode === "scalaire" ? "k: " + texte + "\n" : texte, groupe }); };
for (const s of BASES) ajouter("scalaire", s, "liste");
for (const d of DOCUMENTS) ajouter("document", d, "liste");
const nListe = cas.length;
for (let i = 0; i < N_HASARD; i++) ajouter("scalaire", aleatoire(), "hasard");
for (let i = 0; i < Math.max(50, N_HASARD / 10); i++) ajouter("document", documentAleatoire(), "hasard");

// ---------- Comparaison ----------
const egal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
function comparer(c, reel, v) {
  const r = sim.simuler({ mode: c.mode, texte: c.texte });
  const differences = [];
  if (r.limites.length) return { limite: r.limites[0], differences };
  const s = r.erreurSyntaxe ?? r.versions[v] ?? null;
  if (!s) { differences.push("le simulateur ne rend rien"); return { differences }; }
  const attendu = r.erreurSyntaxe ? { ok: false, ...r.erreurSyntaxe, message: r.erreurSyntaxe.variantes?.[v] ?? r.erreurSyntaxe.message } : s.ok ? s : { ok: false, ...s.erreur };
  if (!reel.ok) {
    if (attendu.ok) differences.push(`l'analyseur refuse (${reel.classe} : ${reel.message}), le simulateur lit ${s.repr}`);
    else {
      if (reel.classe !== attendu.classe) differences.push(`classe d'erreur : réel ${reel.classe}, simulateur ${attendu.classe}`);
      else if (reel.classe !== "DuplicateKeyError" && reel.message !== attendu.message) differences.push(`message : réel « ${reel.message} », simulateur « ${attendu.message} »`);
    }
    return { differences };
  }
  if (!attendu.ok) { differences.push(`le simulateur refuse (${attendu.classe} : ${attendu.message}), l'analyseur lit ${JSON.stringify(reel.arbre)}`); return { differences }; }
  const arbreSim = c.mode === "scalaire" ? s.arbre : s.arbre;
  if (!egal(reel.arbre, arbreSim)) differences.push(`valeur : réel ${JSON.stringify(reel.arbre)}, simulateur ${JSON.stringify(arbreSim)}`);
  if (reel.repr !== undefined && c.mode === "scalaire" && reel.repr !== s.repr) differences.push(`repr : réel ${reel.repr}, simulateur ${s.repr}`);
  if (!egal(reel.json.texte, s.json.texte) || !egal(reel.json.erreur, s.json.erreur))
    differences.push(`JSON : réel ${JSON.stringify(reel.json)}, simulateur ${JSON.stringify(s.json)}`);
  return { differences };
}

try { image(); } catch (e) { console.error("ÉCHEC :", e.message); process.exit(2); }
const reels = analyseursReels(cas);
const [paquetYaml, paquetRuamel, interprete] = versions();
let ecarts = 0, comparaisons = 0, limites = 0, nLimites = new Set();
const parGroupe = { liste: 0, hasard: 0 };
cas.forEach((c, i) => {
  const lignes = [];
  let limiteDuCas = null;
  for (const v of ["1.1", "1.2"]) {
    const { differences, limite } = comparer(c, reels[i][v], v);
    if (limite) { limiteDuCas = limite; continue; }
    comparaisons++;
    for (const d of differences) lignes.push(`  [${v}] ${d}`);
  }
  if (limiteDuCas) { limites++; nLimites.add(limiteDuCas); }
  if (lignes.length) { ecarts++; console.log(`ÉCART ${c.mode === "document" ? "doc" : "scalaire"} ${JSON.stringify(c.texte)}\n${lignes.join("\n")}`); }
  else if (LISTE && c.groupe === "liste") console.log(`accord ${limiteDuCas ? "(limite)" : "        "} ${JSON.stringify(c.texte)}`);
  parGroupe[c.groupe]++;
});
console.log(`\n${cas.length} cas (${nListe} de la liste, ${cas.length - nListe} tirés au hasard, graine ${GRAINE}), ${comparaisons} comparaisons version par version,`
  + ` ${limites} cas déclarés hors de portée (${nLimites.size} limitations différentes), comparés à ${paquetYaml} (PyYAML) et ${paquetRuamel} (ruamel.yaml), Python ${interprete.split(" ")[0]} : ${ecarts === 0 ? "aucun écart" : ecarts + " écart(s)"}.`);
process.exit(ecarts ? 1 : 0);
