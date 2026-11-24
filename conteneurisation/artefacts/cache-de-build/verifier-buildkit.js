#!/usr/bin/env node
// verifier-buildkit.js — confronte le simulateur au vrai BuildKit.
// Joue une suite de manipulations tirées au hasard (modifier une instruction ou un fichier, déplacer une ligne,
// vider le cache, --no-cache), les applique à la fois à l’artefact et à un vrai `docker build`, et compare,
// étape par étape, CACHED et DONE. Les commandes RUN employées n’ont pas besoin du réseau.
//
// Prérequis : Docker (l’image debian:13 présente), Node.js et Playwright ; la page compilée à côté du script.
//   typst compile --root . --font-path commun/fonts --features html --format html \
//     conteneurisation/artefacts/cache-de-build/cache-de-build.typ conteneurisation/artefacts/cache-de-build/index.html
//   node conteneurisation/artefacts/cache-de-build/verifier-buildkit.js [nombre de builds] [graine]
// Le script vide le cache de build de Docker (`docker builder prune -af`) : à lancer sur une machine d’essai.
const { chromium } = require("playwright");
const { execFileSync, spawnSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");

const builds = +(process.argv[2] ?? 40);
let graine = +(process.argv[3] ?? 20261124);
// Générateur congruentiel : on tire dans les bits de poids fort, les seuls bien mélangés.
const hasard = n => { graine = (graine * 1103515245 + 12345) % 2147483648; return Math.floor(graine / 65536) % n; };
const parmi = liste => liste[hasard(liste.length)];

// Les formes que le simulateur dit équivalentes (casse, espaces, commentaire, instructions de configuration)
// sont dans le lot exprès : BuildKit doit les juger équivalentes aussi.
const INSTRUCTIONS = [
  "RUN echo a > /srv/a", "run echo a > /srv/a", "RUN   echo a > /srv/a", "RUN echo a  > /srv/a", "RUN echo b > /srv/b",
  "COPY index.php /srv/", "copy index.php /srv/", "COPY   index.php   /srv/", "COPY index.php /srv/x/", "COPY site.conf /srv/",
  'CMD ["sleep", "1"]', "LABEL a=b", "EXPOSE 80", 'ENTRYPOINT ["sleep"]', "# un commentaire",
];
const CONTENUS = { "index.php": ["bonjour", "salut"], "site.conf": ["conf", "conf2"] };

(async () => {
  const dossier = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-buildkit-"));
  const navigateur = await chromium.launch();
  const page = await navigateur.newPage({ viewport: { width: 1366, height: 800 } });
  await page.goto("file://" + path.join(__dirname, "index.html"));
  await page.getByLabel("sans attente").check();
  execFileSync("docker", ["builder", "prune", "-af"], { stdio: "ignore" });

  const champs = () => page.locator(".dockerfile input");
  const fichier = nom => page.locator(`.contexte input[data-fichier="${nom}"]`);
  // Le simulateur : CACHED ou DONE pour chaque étape qui crée une couche, dans l’ordre.
  const simuler = async sansCache => {
    await page.getByRole("button", { name: sansCache ? "docker image build --no-cache" : "docker image build", exact: true }).click();
    await page.waitForFunction(() => /^Build n°|^ERROR|^Limitation/.test(document.querySelector(".bilan").textContent));
    const bilan = await page.locator(".bilan").textContent();
    if (!bilan.startsWith("Build")) throw new Error("le simulateur refuse ce Dockerfile : " + bilan);
    return (await page.locator(".dockerfile .statut").allTextContents()).map(s => s.split(" ")[0]).filter(s => s === "CACHED" || s === "DONE");
  };
  // Le vrai BuildKit, sur le même Dockerfile et les mêmes fichiers.
  const construire = async sansCache => {
    fs.writeFileSync(path.join(dossier, "Dockerfile"), (await champs().evaluateAll(l => l.map(e => e.value))).join("\n") + "\n");
    for (const nom of Object.keys(CONTENUS)) fs.writeFileSync(path.join(dossier, nom), await fichier(nom).inputValue() + "\n");
    const r = spawnSync("docker", ["build", "--progress=plain", ...(sansCache ? ["--no-cache"] : []), "-t", "verifier-buildkit", dossier], { encoding: "utf8" });
    if (r.status !== 0) throw new Error("docker build a échoué :\n" + r.stderr.split("\n").filter(l => l.includes("ERROR")).join("\n"));
    const etapes = {}, etats = {};
    for (const ligne of r.stderr.split("\n")) {
      let m = ligne.match(/^#(\d+) \[\s*(\d+)\/\d+\] /);
      if (m) { etapes[m[1]] = +m[2]; continue; }
      m = ligne.match(/^#(\d+) (CACHED|DONE)/);
      if (m && m[1] in etapes) etats[m[1]] = m[2];
    }
    return Object.keys(etapes).filter(n => etapes[n] > 1).sort((a, b) => etapes[a] - etapes[b]).map(n => etats[n]);
  };

  // Départ : quatre instructions sans réseau à la place de celles de la page.
  for (const [i, texte] of ["COPY index.php /srv/", "RUN echo a > /srv/a", "COPY site.conf /srv/", 'CMD ["sleep", "1"]'].entries()) await champs().nth(i + 1).fill(texte);
  for (const nom of Object.keys(CONTENUS)) await fichier(nom).fill(CONTENUS[nom][0]);

  let ecarts = 0;
  for (let n = 1; n <= builds; n++) {
    const quoi = hasard(10);
    let action;
    if (quoi < 3) { const i = 1 + hasard(4), texte = parmi(INSTRUCTIONS); await champs().nth(i).fill(texte); action = `ligne ${i + 1} ← ${texte}`; }
    else if (quoi < 5) { const nom = parmi(Object.keys(CONTENUS)), contenu = parmi(CONTENUS[nom]); await fichier(nom).fill(contenu); action = `${nom} ← ${contenu}`; }
    else if (quoi < 7) { const i = 2 + hasard(3); await page.getByRole("button", { name: `Descendre l’instruction ${i}` }).click(); action = `ligne ${i} descendue`; }
    else if (quoi === 7) { await page.getByRole("button", { name: "Vider le cache" }).click(); execFileSync("docker", ["builder", "prune", "-af"], { stdio: "ignore" }); action = "cache vidé"; }
    else action = "rien";
    const sansCache = hasard(12) === 0;
    const simule = await simuler(sansCache), reel = await construire(sansCache);
    const accord = simule.join(" ") === reel.join(" ");
    if (!accord) ecarts++;
    console.log(`${String(n).padStart(3)}. ${accord ? "accord" : "ÉCART "} | ${(action + (sansCache ? " ; --no-cache" : "")).padEnd(44)} | ${simule.join(" ")}${accord ? "" : "   ≠ BuildKit : " + reel.join(" ")}`);
    if (!accord) console.log("     Dockerfile : " + (await champs().evaluateAll(l => l.map(e => e.value))).join(" ⏎ "));
  }
  await navigateur.close();
  fs.rmSync(dossier, { recursive: true });
  const version = execFileSync("docker", ["version", "--format", "{{.Server.Version}}"], { encoding: "utf8" }).trim();
  console.log(`\n${builds} builds comparés à BuildKit (Docker Engine ${version}) : ${ecarts === 0 ? "aucun écart" : ecarts + " écart(s)"}.`);
  process.exit(ecarts ? 1 : 0);
})().catch(e => { console.error("ÉCHEC :", e.message); process.exit(2); });
