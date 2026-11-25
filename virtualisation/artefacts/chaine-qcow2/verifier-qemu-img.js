#!/usr/bin/env node
// verifier-qemu-img.js — confronte le simulateur aux vrais outils qemu-img et qemu-io.
// Chaque cas est une suite d'opérations (écrire, lire, adosser, commit, rebase) rejouée deux fois : dans le simulateur
// (chaine-qcow2.js, importé tel quel, sans navigateur) et avec les vrais outils, dans un dossier temporaire :
//   qemu-img create -f qcow2 base.qcow2 1M ; qemu-img create -f qcow2 -b <base> -F qcow2 vmN.qcow2 1M
//   qemu-io -c "write -P 0xNN <décalage> <taille>" ; qemu-io -c "read -P 0xNN …" ; qemu-img commit ; qemu-img rebase
// Après chaque opération, pour chaque image, il compare :
//   - la chaîne (`qemu-img info --backing-chain --output=json`) ;
//   - la provenance de chaque grappe (`qemu-img map --output=json` : depth, present) ;
//   - le contenu de chaque grappe (`qemu-io -r -c "read -P …"`, motif attendu par le simulateur) ;
//   - l'occupation sur l'hôte (« actual-size » de `qemu-img info`, ce que lit `ls -s`) ; pour une image vidée par commit,
//     QEMU peut en compter 4 Kio de plus selon le système de fichiers : l'écart de 4 Kio est toléré, pas davantage.
// Les cas : les cinq recettes de la page, des cas limites (commit sans base, image vide, rebase sans changement,
// rebase vers aucune base…), puis des suites d'opérations tirées au hasard avec une graine.
//   node virtualisation/artefacts/chaine-qcow2/verifier-qemu-img.js [--graine N] [--cas N]
// Prérequis : qemu-img et qemu-io (paquet qemu-utils) ; ni KVM ni libvirt.
const { spawnSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const S = require("./chaine-qcow2.js");

const arg = (nom, defaut) => { const i = process.argv.indexOf(nom); return i > 0 ? +process.argv[i + 1] : defaut; };
const GRAINE = arg("--graine", 20260), ALEATOIRES = arg("--cas", 120);
const TAILLE = S.GRAPPES * S.KIO_GRAPPE * 1024, GR = S.KIO_GRAPPE * 1024;
let dossier;
const outil = (cmd, args) => spawnSync(cmd, args, { encoding: "utf8", cwd: dossier });
const img = (...a) => outil("qemu-img", a);
const io = (image, ...cmds) => outil("qemu-io", ["-r", "-f", "qcow2", ...cmds.flatMap(c => ["-c", c]), image]);

// Générateur pseudo-aléatoire à graine (mulberry32).
function hasard(graine) { let a = graine >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// Rejoue une opération avec les vrais outils ; rend les écarts constatés sur l'opération elle-même.
function rejouer(op, r) {
  const ecarts = [];
  if (op.op === "creer") {
    const x = img("create", "-q", "-f", "qcow2", "-b", op.base, "-F", "qcow2", r.nom, "1M");
    if (x.status !== 0) ecarts.push(`qemu-img create a échoué : ${x.stderr.trim()}`);
  } else if (op.op === "ecrire") {
    const x = outil("qemu-io", ["-f", "qcow2", "-c", `write -P 0x${S.hex(op.motif)} ${op.grappe * GR} ${op.nombre * GR}`, op.image]);
    if (x.status !== 0 || /error|failed/i.test(x.stdout + x.stderr)) ecarts.push(`qemu-io write a échoué : ${(x.stdout + x.stderr).trim()}`);
  } else if (op.op === "lire") {
    const bon = io(op.image, `read -P 0x${S.hex(r.motif)} ${op.grappe * GR} ${GR}`);
    if (/Pattern verification failed/.test(bon.stdout + bon.stderr)) ecarts.push(`la grappe ${op.grappe} de ${op.image} ne contient pas ${S.hex(r.motif)} dans qemu-io`);
    const faux = io(op.image, `read -P 0x${S.hex(r.motif ^ 0xff)} ${op.grappe * GR} ${GR}`);
    if (!/Pattern verification failed/.test(faux.stdout + faux.stderr)) ecarts.push("qemu-io n'a pas détecté un motif faux (la lecture ne prouve rien)");
  } else if (op.op === "commit") {
    const x = img("commit", "-q", "-f", "qcow2", op.image);
    if (r.erreur) { if (x.status === 0 || !x.stderr.includes(r.erreur)) ecarts.push(`qemu-img commit devait refuser (« ${r.erreur} ») : statut ${x.status}, ${x.stderr.trim()}`); }
    else if (x.status !== 0) ecarts.push(`qemu-img commit a échoué : ${x.stderr.trim()}`);
  } else if (op.op === "rebase") {
    const x = img("rebase", "-q", "-f", "qcow2", ...(op.base ? ["-b", op.base, "-F", "qcow2"] : ["-b", ""]), op.image);
    if (x.status !== 0) ecarts.push(`qemu-img rebase a échoué : ${x.stderr.trim()}`);
  }
  return ecarts;
}

// Compare l'état entier du simulateur à celui des fichiers.
function comparer(etat) {
  const ecarts = [];
  for (const { nom } of etat.images) {
    const sim = S.chaine(etat, nom);
    const info = JSON.parse(img("info", "--backing-chain", "--output=json", nom).stdout || "[]");
    const reel = info.map(i => i.filename);
    if (JSON.stringify(reel) !== JSON.stringify(sim)) ecarts.push(`${nom} chaîne : qemu ${JSON.stringify(reel)} ≠ simulateur ${JSON.stringify(sim)}`);
    if (info[0]) {
      // « actual-size » : les blocs du fichier, ce que lit `ls -s`. Une image vidée par commit peut en compter 4 Kio de plus
      // selon le système de fichiers (le trou creusé par la libération) : on accepte alors l'écart de 4 Kio, pas davantage.
      const reel_kio = info[0]["actual-size"] / 1024, attendu = S.occupation(etat, nom), videe = S.image(etat, nom).videe;
      if (reel_kio !== attendu && !(videe && reel_kio === attendu + 4)) ecarts.push(`${nom} occupation : qemu ${reel_kio} Kio ≠ simulateur ${attendu} Kio${videe ? " (image vidée par commit : 4 Kio de tolérance)" : ""}`);
      if (info[0]["virtual-size"] !== TAILLE) ecarts.push(`${nom} taille virtuelle ${info[0]["virtual-size"]}`);
    }
    // provenance : qemu-img map
    const carte = JSON.parse(img("map", "--output=json", nom).stdout || "[]");
    const vue = S.vue(etat, nom);
    for (let k = 0; k < S.GRAPPES; k++) {
      const e = carte.find(x => x.start <= k * GR && k * GR < x.start + x.length);
      const f = e && e.present ? sim[e.depth] ?? `depth ${e.depth}` : null;
      if (f !== vue[k].fournisseur) ecarts.push(`${nom} grappe ${k} fournie par : qemu ${f} ≠ simulateur ${vue[k].fournisseur}`);
    }
    // contenu : qemu-io read -P, une commande par grappe
    const x = io(nom, ...vue.map((g, k) => `read -P 0x${S.hex(g.motif)} ${k * GR} ${GR}`));
    const sortie = x.stdout + x.stderr;
    const faux = [...sortie.matchAll(/Pattern verification failed at offset (\d+)/g)].map(m => Math.floor(+m[1] / GR));
    for (const k of new Set(faux)) ecarts.push(`${nom} grappe ${k} contenu : qemu-io ne lit pas ${S.hex(vue[k].motif)}`);
    if (!faux.length && x.status !== 0) ecarts.push(`${nom} : qemu-io read a échoué : ${sortie.trim().slice(0, 200)}`);
  }
  return ecarts;
}

// ---------- Les cas ----------
const B = S.BASE, ecrire = (image, grappe, motif, nombre = 1) => ({ op: "ecrire", image, grappe, nombre, motif });
const adosser = base => ({ op: "creer", base }), lire = (image, grappe) => ({ op: "lire", image, grappe });
const commit = image => ({ op: "commit", image }), rebase = (image, base) => ({ op: "rebase", image, base });
const m1 = ecrire(B, 0, 0xaa, S.GRAPPES);
const cas = [
  ["recette 1 : copie sur écriture", [m1, adosser(B), ecrire("vm1.qcow2", 0, 0xbb), lire("vm1.qcow2", 5), lire("vm1.qcow2", 0)]],
  ["recette 2 : une VM de plus", [m1, adosser(B), adosser(B), ecrire("vm2.qcow2", 3, 0xcc)]],
  ["recette 3 : danger, écrire dans la base", [m1, adosser(B), adosser(B), ecrire("vm1.qcow2", 0, 0xbb), ecrire(B, 0, 0xdd), ecrire(B, 5, 0xdd)]],
  ["recette 4 : chaîne à trois étages, commit", [m1, adosser(B), ecrire("vm1.qcow2", 1, 0xbb), adosser("vm1.qcow2"), ecrire("vm2.qcow2", 2, 0xcc),
    lire("vm2.qcow2", 0), lire("vm2.qcow2", 1), lire("vm2.qcow2", 2), commit("vm2.qcow2")]],
  ["recette 5 : rebase puis aplatir", [m1, adosser(B), ecrire("vm1.qcow2", 1, 0xbb), adosser("vm1.qcow2"), ecrire("vm2.qcow2", 2, 0xcc), rebase("vm2.qcow2", B), rebase("vm2.qcow2", null)]],
  ["commit d'une image sans base (refusé)", [commit(B)]],
  ["commit d'une image vide", [m1, adosser(B), commit("vm1.qcow2")]],
  ["commit d'une base vide : la table L2 apparaît", [adosser(B), adosser("vm1.qcow2"), ecrire("vm2.qcow2", 4, 0xee), commit("vm2.qcow2"), commit("vm1.qcow2")]],
  ["rebase sur la même base, sans changement", [m1, adosser(B), ecrire("vm1.qcow2", 2, 0xbb), rebase("vm1.qcow2", B)]],
  ["rebase d'une image vide sur aucune base", [adosser(B), rebase("vm1.qcow2", null)]],
  ["rebase : des zéros copiés", [ecrire(B, 0, 0xaa, 3), adosser(B), ecrire("vm1.qcow2", 4, 0xbb), adosser("vm1.qcow2"), rebase("vm2.qcow2", null), ecrire(B, 8, 0xcc, 2)]],
  ["rebase vers une image voisine", [ecrire(B, 0, 0xaa, 4), adosser(B), adosser(B), ecrire("vm1.qcow2", 1, 0xbb), ecrire("vm2.qcow2", 2, 0xcc), rebase("vm1.qcow2", "vm2.qcow2"), commit("vm1.qcow2")]],
  ["écrire dans la base d'une chaîne, puis commit", [m1, adosser(B), adosser("vm1.qcow2"), ecrire(B, 3, 0xdd), ecrire("vm1.qcow2", 3, 0xbb), commit("vm2.qcow2"), ecrire(B, 3, 0xee), commit("vm1.qcow2")]],
  ["écrire deux fois la même grappe", [adosser(B), ecrire("vm1.qcow2", 7, 0xaa), ecrire("vm1.qcow2", 7, 0xbb), ecrire("vm1.qcow2", 6, 0xcc, 3), lire("vm1.qcow2", 8)]],
];

function suiteAleatoire(alea) {
  let etat = S.depart();
  const ops = [], choix = liste => liste[Math.floor(alea() * liste.length)];
  const n = 6 + Math.floor(alea() * 9);
  for (let i = 0; i < n; i++) {
    const noms = etat.images.map(x => x.nom), t = alea();
    let op;
    if (t < .35) { op = ecrire(choix(noms), Math.floor(alea() * S.GRAPPES), choix(S.MOTIFS), alea() < .75 ? 1 : 1 + Math.floor(alea() * 4)); op.nombre = Math.min(op.nombre, S.GRAPPES - op.grappe); }
    else if (t < .5 && noms.length < S.MAX_IMAGES) op = adosser(choix(noms));
    else if (t < .6) op = lire(choix(noms), Math.floor(alea() * S.GRAPPES));
    else if (t < .8) op = commit(choix(noms));
    else {
      const image = choix(noms), interdites = [image, ...S.descendants(etat, image)];
      op = rebase(image, choix([null, ...noms.filter(x => !interdites.includes(x))]));
    }
    ops.push(op); etat = S.appliquer(etat, op).etat;
  }
  return ops;
}
const alea = hasard(GRAINE);
for (let i = 0; i < ALEATOIRES; i++) cas.push([`aléatoire ${i + 1} (graine ${GRAINE})`, suiteAleatoire(alea)]);

// ---------- Exécution ----------
const decrire = op => op.op === "creer" ? `adosser(${op.base})` : op.op === "ecrire" ? `écrire(${op.image}, ${op.grappe}${op.nombre > 1 ? "+" + op.nombre : ""}, ${S.hex(op.motif)})`
  : op.op === "lire" ? `lire(${op.image}, ${op.grappe})` : op.op === "commit" ? `commit(${op.image})` : `rebase(${op.image}, ${op.base})`;
let ecartsTotal = 0, operations = 0;
dossier = os.tmpdir();
const version = outil("qemu-img", ["--version"]).stdout.split("\n")[0];
for (const [titre, ops] of cas) {
  dossier = fs.mkdtempSync(path.join(os.tmpdir(), "verifier-qemu-img-"));
  const ecarts = [];
  let etat = S.depart();
  img("create", "-q", "-f", "qcow2", S.BASE, "1M");
  ecarts.push(...comparer(etat).map(e => `départ : ${e}`));
  for (const op of ops) {
    const r = S.appliquer(etat, op);
    operations++;
    const avant = ecarts.length;
    if (!(op.op === "creer" && r.erreur)) ecarts.push(...rejouer(op, r).map(e => `${decrire(op)} : ${e}`));
    etat = r.etat;
    ecarts.push(...comparer(etat).map(e => `après ${decrire(op)} : ${e}`));
    if (ecarts.length > avant + 8) break;
  }
  fs.rmSync(dossier, { recursive: true });
  if (ecarts.length) ecartsTotal++;
  console.log(`${ecarts.length ? "ÉCART " : "accord"} | ${titre} | ${ops.length} opérations`);
  for (const e of ecarts.slice(0, 10)) console.log("       " + e);
}
console.log(`\n${cas.length} cas (${operations} opérations, chacune comparée sur toutes les images) comparés à ${version} : ${ecartsTotal === 0 ? "aucun écart" : ecartsTotal + " cas en écart"}.`);
process.exit(ecartsTotal ? 1 : 0);
