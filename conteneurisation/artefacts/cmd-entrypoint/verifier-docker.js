#!/usr/bin/env node
// verifier-docker.js — confronte le simulateur au vrai Docker.
// Pour chaque cas (image de base × forme d'ENTRYPOINT × forme de CMD × lancement), construit une petite image,
// lance un conteneur et compare au simulateur (cmd-entrypoint.js, importé tel quel, sans navigateur) :
//   - argv : Path et Args de `docker container inspect` ;
//   - Config.Entrypoint et Config.Cmd, de l'image (`docker image inspect`) et du conteneur ;
//   - /proc/1/cmdline, lu par `docker exec` : qui porte le PID 1 ;
//   - les paramètres que le programme final a reçus ;
//   - l'arrêt : `docker container stop` rend 0 si le PID 1 est le programme, 137 si c'est sh.
// Les lancements : sans argument, `x y`, `--entrypoint e3`, `--entrypoint e3` et `x y`. Les deux bases : debian:13-slim
// (CMD ["bash"] hérité) et une image sans commande (CMD []), ce qui couvre l'héritage du CMD et sa remise à vide
// quand le Dockerfile déclare un ENTRYPOINT. Deux cas de limites : un programme inconnu, un script shell dans les arguments.
//
// Les programmes e1, e3, c1 et x sont un même petit script : il note son nom et ses paramètres dans /tmp/argv, puis
// attend en gérant SIGTERM. Un script lancé directement apparaît dans /proc/1/cmdline sous la forme
// « /bin/sh /usr/local/bin/<nom> … » (le noyau ajoute l'interpréteur) : le script retire ce préfixe avant de comparer.
//
// Prérequis : Docker, Node.js ; l'image debian:13-slim déjà présente (sinon `docker pull debian:13-slim`).
//   node conteneurisation/artefacts/cmd-entrypoint/verifier-docker.js
// Il ne touche qu'à ses conteneurs (artefact-ce-*) et à ses images (artefact-ce-*) ; aucun prune.
const { spawnSync, execFileSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const { simuler, depart, TEXTE_ENTRYPOINT, TEXTE_CMD } = require("./cmd-entrypoint.js");

const BASE = "debian:13-slim";
const docker = (args, options = {}) => spawnSync("docker", args, { encoding: "utf8", ...options });
const mots = liste => (liste ?? []).map(x => x.mot);
const normaliser = liste => liste && liste.length ? liste : null;   // Docker écrit null ou [] selon les cas

const SONDE = `#!/bin/sh
{ echo "\${0##*/}"; for a in "$@"; do echo "$a"; done; } > /tmp/argv.tmp && mv /tmp/argv.tmp /tmp/argv
trap 'exit 0' TERM
sleep 120 &
wait
`;
const construire = (etiquette, dockerfile, contexte) => {
  const r = docker(["build", "-q", "-t", etiquette, "-f", "-", contexte], { input: dockerfile });
  if (r.status !== 0) throw new Error(`docker build ${etiquette} a échoué :\n${r.stderr}`);
};
const ligne = (instruction, forme, texte) => forme === "absent" ? ""
  : `${instruction} ${forme === "exec" ? JSON.stringify(texte.split(" ")) : texte}\n`;

const cas = [];
for (const base of ["bash", "vide"]) for (const e of ["absent", "exec", "shell"]) for (const c of ["absent", "exec", "shell"]) {
  for (const [option, args] of [["", ""], ["", "x y"], ["e3", ""], ["e3", "x y"]]) cas.push({ ...depart(), base, entrypoint: e, cmd: c, option, args });
}
cas.push({ ...depart(), option: "foo", args: "", attendu: "inconnu" });                       // programme inconnu
cas.push({ ...depart(), entrypoint: "absent", cmd: "absent", args: "/bin/sh -c x", attendu: "script" });   // script shell dans les arguments

(async () => {
  const dossier = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-docker-"));
  fs.writeFileSync(path.join(dossier, "sonde"), SONDE);
  const nettoyer = () => {
    const liste = docker(["container", "ls", "-aq", "--filter", "name=^artefact-ce-"]).stdout.split("\n").filter(Boolean);
    if (liste.length) docker(["container", "rm", "-f", ...liste]);
  };
  nettoyer();
  const images = new Set();
  const etiquette = e => `artefact-ce-${e.base}-${e.entrypoint}-${e.cmd}`;
  // Les bases : debian:13-slim et les programmes d'essai ; puis la même sans commande.
  construire("artefact-ce-base-bash", `FROM ${BASE}\nCOPY sonde /usr/local/bin/sonde\nRUN chmod +x /usr/local/bin/sonde && for n in e1 e3 c1 x; do cp /usr/local/bin/sonde /usr/local/bin/$n; done && rm /usr/local/bin/sonde\n`, dossier);
  construire("artefact-ce-base-vide", "FROM artefact-ce-base-bash\nCMD []\n", dossier);
  images.add("artefact-ce-base-bash"); images.add("artefact-ce-base-vide");
  const dockerfile = e => `FROM artefact-ce-base-${e.base}\n${ligne("ENTRYPOINT", e.entrypoint, TEXTE_ENTRYPOINT)}${ligne("CMD", e.cmd, TEXTE_CMD)}`;
  for (const e of cas) {
    const tag = etiquette(e);
    if (!images.has(tag)) { construire(tag, dockerfile(e), dossier); images.add(tag); }
  }

  let ecarts = 0, n = 0;
  for (const e of cas) {
    n++;
    const sim = simuler(e), tag = etiquette(e), nom = `artefact-ce-${n}`;
    const mots_args = e.args.trim() ? e.args.trim().split(/\s+/) : [];
    const options = e.option ? ["--entrypoint", e.option] : [];
    const r = docker(["run", "-d", "-it", "--name", nom, ...options, tag, ...mots_args]);
    const differences = [];
    const ecart = texte => differences.push(texte);

    if (sim.erreur) {
      if (r.status === 0 || !r.stderr.includes(sim.erreur)) ecart(`Docker devait refuser (« ${sim.erreur} ») : statut ${r.status}, ${r.stderr.trim().split("\n")[0]}`);
    } else if (e.attendu === "inconnu") {
      if (r.status === 0 || !/executable file not found/.test(r.stderr)) ecart("Docker devait échouer avec « executable file not found »");
      if (!sim.limites.length || sim.pid1) ecart("le simulateur devait afficher une limitation, sans PID 1");
    } else if (r.status !== 0) {
      ecart("docker run a échoué : " + r.stderr.trim().split("\n")[0]);
    } else {
      const inspection = JSON.parse(docker(["container", "inspect", nom]).stdout)[0];
      const image = JSON.parse(docker(["image", "inspect", tag]).stdout)[0];
      const comparer = (quoi, reel, simule) => { if (JSON.stringify(reel) !== JSON.stringify(simule)) ecart(`${quoi} : Docker ${JSON.stringify(reel)} ≠ simulateur ${JSON.stringify(simule)}`); };
      comparer("argv (Path + Args)", [inspection.Path, ...inspection.Args], mots(sim.argv));
      comparer("image Config.Entrypoint", normaliser(image.Config.Entrypoint), normaliser(mots(sim.image.entrypoint)));
      comparer("image Config.Cmd", normaliser(image.Config.Cmd), normaliser(mots(sim.image.cmd)));
      comparer("conteneur Config.Entrypoint", normaliser(inspection.Config.Entrypoint), normaliser(mots(sim.conteneur.entrypoint)));
      comparer("conteneur Config.Cmd", normaliser(inspection.Config.Cmd), normaliser(mots(sim.conteneur.cmd)));
      // PID 1 : /proc/1/cmdline, sans le préfixe que le noyau ajoute à un script.
      const cmdline = spawnSync("docker", ["exec", nom, "cat", "/proc/1/cmdline"]).stdout.toString("utf8").split("\0");
      cmdline.pop();
      const pid1 = cmdline[0] === "/bin/sh" && cmdline[1]?.startsWith("/usr/local/bin/") ? [path.basename(cmdline[1]), ...cmdline.slice(2)] : cmdline;
      if (sim.pid1) comparer("/proc/1/cmdline", pid1, sim.pid1);
      else if (e.attendu !== "inconnu") ecart("le simulateur ne donne pas de PID 1");
      // Le programme final et ses paramètres (le script note son nom et ses paramètres).
      if (sim.programme && sim.programme.nom !== "bash") {
        const recu = docker(["exec", nom, "sh", "-c", "for i in $(seq 50); do [ -f /tmp/argv ] && break; sleep 0.1; done; cat /tmp/argv"]).stdout.split("\n");
        recu.pop();
        comparer("programme final et ses paramètres", recu, [sim.programme.nom, ...sim.programme.args]);
      }
      if (e.attendu === "script" && !sim.limites.length) ecart("le simulateur devait afficher une limitation");
      // L'arrêt : 0 si le PID 1 est le programme (il gère SIGTERM), 137 si c'est sh (qui ne relaie pas).
      if (sim.programme && sim.programme.nom !== "bash") {
        docker(["stop", "-t", "1", nom]);
        const code = +docker(["inspect", "-f", "{{.State.ExitCode}}", nom]).stdout.trim();
        comparer("code de sortie après docker container stop", code, sim.genre === "shell" ? 137 : 0);
      }
    }
    docker(["rm", "-f", nom]);
    if (differences.length) ecarts++;
    const resume = `${e.base === "bash" ? "debian" : "vide  "} E:${e.entrypoint.padEnd(6)} C:${e.cmd.padEnd(6)} ${e.option ? "--entrypoint " + e.option + " " : ""}${e.args}`.trim();
    console.log(`${String(n).padStart(3)}. ${differences.length ? "ÉCART " : "accord"} | ${resume.padEnd(50)} | ${sim.erreur ? "erreur : " + sim.erreur : JSON.stringify(mots(sim.argv))}`);
    for (const d of differences) console.log("       " + d);
  }
  nettoyer();
  for (const tag of images) docker(["image", "rm", tag]);
  fs.rmSync(dossier, { recursive: true });
  const version = execFileSync("docker", ["version", "--format", "{{.Server.Version}}"], { encoding: "utf8" }).trim();
  console.log(`\n${cas.length} cas comparés à Docker Engine ${version} (base ${BASE}) : ${ecarts === 0 ? "aucun écart" : ecarts + " écart(s)"}.`);
  process.exit(ecarts ? 1 : 0);
})().catch(e => { console.error("ÉCHEC :", e.message); process.exit(2); });
