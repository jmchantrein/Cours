// tester-vm.mjs — démarre l'image de la VM dans Node (v86 de vendor/), exécute des commandes par le port série,
// comme la page, et vérifie leurs sorties. Usage, après preparer.sh --vm, depuis n'importe où :
//   node commun/terminal/tester-vm.mjs [outil …]   les outils de construire-vm.sh (ou ceux nommés), le compte ada,
//                                                  puis le rejeu de chaque TP et de chaque page de cours en mode vm
//                                                  (4 à la fois)
//   node commun/terminal/tester-vm.mjs --tp <cours>/tp/<tp>   le rejeu d'un seul TP (ou --tp <cours>/pages/<module>)
//
// Rejeu d'un TP : le script compile son énoncé en HTML (typst), en lit les blocs terminal avec le découpage de
// commandes de commun/tp.js (une commande = ce que le bouton « Exécuter » envoie), et envoie chaque commande à
// la VM, dans l'ordre, jusqu'à l'invite suivante. Il vérifie ensuite, par TP (SPECS ci-dessous) : les fichiers de
// départ, la première et la dernière commande contre la sortie annoncée, et qu'aucune commande n'échoue sans que
// l'énoncé le dise (« command not found », « No such file »…).
// Rejeu d'une page de cours (<cours>/pages/<module>/) : même lecture, mais plus stricte, car la page promet que chaque
// commande cliquée dans l'ordre donne ce qu'elle annonce : la sortie de chaque commande est comparée à l'annonce (pour
// `ls`, les noms, quelle que soit la largeur du terminal), et le repère de contexte que la page déclare (le modèle de
// contexte.js) au contexte réel que la VM décrit après chaque commande (vm/contexte.bash) : répertoire courant, et
// contenu de chaque répertoire que la page déclare.
import { createRequire } from "node:module";
import { readFileSync, readdirSync, existsSync, mkdtempSync, rmSync } from "node:fs";
import { execFileSync, spawn } from "node:child_process";
import os from "node:os";
import path from "node:path";

const ici = import.meta.dirname;
const utf8demarrage = s => Buffer.from(s, "latin1").toString("utf8");
const racine = path.resolve(ici, "../..");
const vendor = path.join(ici, "vendor");

// ---------------------------------------------------------------- la VM, pilotée comme la page
// etat : l'état de départ de la page (data-depart, data-ici), passé au noyau comme le fait terminal.js.
async function demarrerVM(etat = {}) {
  const { V86 } = createRequire(import.meta.url)(path.join(vendor, "libv86.js"));
  const manifeste = JSON.parse(readFileSync(path.join(vendor, "vm/manifeste.json"), "utf8"));
  const lire = f => { const b = readFileSync(path.join(vendor, f)); return b.buffer.slice(b.byteOffset, b.byteOffset + b.length); };
  const debut = Date.now();
  const vm = new V86({
    wasm_fn: async env => (await WebAssembly.instantiate(lire("v86.wasm"), env)).instance.exports,
    bios: { buffer: lire("seabios.bin") }, vga_bios: { buffer: lire("vgabios.bin") },
    bzimage: { buffer: lire("vm/bzImage") }, initrd: { buffer: lire("vm/initrd.gz") },
    cmdline: "console=ttyS0,115200 rdinit=/init quiet terminal=100x30" + (etat.depart ? ` depart=${etat.depart}` : "") + (etat.ici ? ` ici=${etat.ici}` : ""),
    memory_size: manifeste.memoire_mo * 1024 * 1024, autostart: true, disable_keyboard: true, disable_mouse: true,
  });
  let sortie = "", attente = null, compte = 0;
  // L'invite de bash : précédée de l'activation du collage balisé (\x1b[?2004h), pour ne pas la confondre avec une ligne de
  // sortie qui finit par « # » ou « $ » (un commentaire, un diff).
  const INVITE = /\x1b\[\?2004h[^\n]*[$#] $/;
  const bruit = s => s.replace(/\x1b\][^\x07]*\x07/g, "").replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "").replace(/\x1b[=>]/g, "").replace(/\r/g, "");
  vm.add_listener("serial0-output-byte", octet => {
    sortie += String.fromCharCode(octet);
    if (attente && attente.motif.test(sortie.slice(attente.depuis))) { const a = attente; attente = null; clearTimeout(a.minuteur); a.fini(); }
  });
  const attendre = (motif, delai, depuis = sortie.length) => new Promise((fini, rate) => {
    if (motif.test(sortie.slice(depuis))) return fini();
    const minuteur = setTimeout(() => { attente = null; rate(new Error(`délai dépassé (${motif})`)); }, delai);
    attente = { motif, depuis, fini, minuteur };
  });
  await attendre(/\x1b\]0;cours-terminal-pret\x07/, 300_000);
  if (/Échec de l'installation de l'état de départ/.test(utf8demarrage(sortie))) throw new Error(`état de départ : échec de ${etat.depart}`);
  await attendre(INVITE, 60_000, sortie.indexOf("cours-terminal-pret\x07"));
  const secondes = ((Date.now() - debut) / 1000).toFixed(1);
  const utf8 = s => Buffer.from(s, "latin1").toString("utf8");
  const taper = texte => { let octets = ""; for (const o of new TextEncoder().encode(texte)) octets += String.fromCharCode(o); vm.serial0_send(octets); };
  return {
    // Envoie des touches telles quelles (sans Entrée ajoutée) ; attend le motif, ou une pause. Rend l'écran nettoyé.
    async toucher(texte, motif = null, delai = 20_000) {
      const depuis = sortie.length;
      taper(texte);
      if (motif) await attendre(motif, delai, depuis); else await new Promise(r => setTimeout(r, 350));
      return { propre: bruit(utf8(sortie.slice(depuis))), brut: utf8(sortie.slice(depuis)) };
    },
    INVITE,
    secondes, version: manifeste.version,
    // Envoie le texte tel que la page le fait (octets UTF-8), attend l'invite suivante, rend la sortie sans l'écho.
    async executer(commande, delai = 60_000, avant = null) {
      const depuis = sortie.length;
      // Fin de commande : sans touches à envoyer, une seconde commande (echo FIN_n) en donne le signal sans ambiguïté ;
      // avec des touches (Vim), on attend que Vim rende l'écran (\x1b[?1049l), puis l'invite de bash.
      const marque = avant ? null : `FIN_${++compte}`;
      const fin = marque ? new RegExp(`[\\r\\n]FIN_${compte}\\r?\\n`) : /\x1b\[\?1049l[\s\S]*\x1b\[\?2004h[^\n]*[$#] $/;
      taper(commande.replace(/\n/g, "\r") + "\r" + (marque ? `echo FIN_$((${compte}+0))\r` : ""));
      if (avant) { await attendre(avant.quand, delai, depuis); await new Promise(r => setTimeout(r, avant.pause)); taper(avant.envoyer); }
      let bloque = false;
      try { await attendre(fin, delai, depuis); } catch { bloque = true; vm.serial0_send("\x03"); await new Promise(r => setTimeout(r, 1500)); }
      let lignes = bruit(utf8(sortie.slice(depuis))).split("\n");
      if (marque) { const k = lignes.findIndex(l => l === marque); if (k >= 0) lignes = lignes.slice(0, k); while (lignes.length && /echo FIN_/.test(lignes.at(-1))) lignes.pop(); }
      // L'écho de la commande : la ligne d'invite, puis une ligne par ligne de la commande au-delà de la première.
      const p = lignes.findIndex(l => /^[\w-]+@cours:\S*[$#] /.test(l));
      lignes = lignes.slice(p >= 0 ? p + commande.split("\n").length : 0);
      if (lignes.length && /^[\w-]+@cours:\S*[$#] ?$/.test(lignes.at(-1))) lignes.pop();
      // Le contexte que le shell décrit avant l'invite qui suit la commande (séquence OSC 6973 de vm/contexte.bash).
      // La dernière avant la ligne FIN_n : la première de la tranche suit encore la commande précédente.
      const brut = utf8(sortie.slice(depuis)), finBrut = marque ? brut.search(new RegExp(`[\\r\\n]${marque}\\r?\\n`)) : -1;
      const contextes = [...(finBrut >= 0 ? brut.slice(0, finBrut) : brut).matchAll(/\x1b\]6973;([^\x07]*)\x07/g)].map(m => m[1]);
      return { sortie: lignes.join("\n"), bloque, contexte: contextes.at(-1) ?? null };
    },
    fermer: () => vm.destroy(),
  };
}

// ---------------------------------------------------------------- outils de l'image, compte ada
async function testerImage(outils) {
  const vm = await demarrerVM();
  console.log(`Invite après ${vm.secondes} s (${vm.version}).`);
  const absents = (await vm.executer(`for c in ${outils.join(" ")}; do command -v $c >/dev/null || echo ABSENT:$c; done`)).sortie
    .split("\n").filter(l => l.startsWith("ABSENT:")).map(l => l.slice(7));
  if (absents.length) throw new Error(`outils absents : ${absents.join(", ")}`);
  const taille = (await vm.executer("stty size")).sortie.trim();
  if (taille !== "30 100") throw new Error(`taille du terminal ${taille}, attendue 30 100`);
  const compte = (await vm.executer("id; pwd; umask; man -w ls >/dev/null && echo man-ok; ps -o ppid= -p 1; bats --version")).sortie;
  for (const motif of [/uid=1000\(ada\) gid=1000\(ada\) groups=1000\(ada\),1001\(etudiants\)/, /^\/home\/ada$/m, /^0002$/m, /^man-ok$/m, /^Bats \d/m])
    if (!motif.test(compte)) throw new Error(`compte ou outil inattendu (${motif}) :\n${compte}`);
  console.log(`${outils.length} outils présents, terminal 100 × 30, compte ada (1000, groupe etudiants), man, ps de procps, bats.`);
  // Fin du shell (Ctrl+D sur une ligne vide) : une nouvelle session s'ouvre dans le répertoire personnel, les fichiers restent.
  await vm.executer("cd /tmp && touch reste.txt");
  await new Promise(r => setTimeout(r, 1500));   // l'invite d'abord : Ctrl+D s'adresse à Readline
  const fin = await vm.toucher("\x04", /Session termin[\s\S]{1,4} ; nouvelle session\.[\s\S]*\x1b\[\?2004h[^\n]*[$#] $/, 60_000);
  const apres = (await vm.executer("pwd; ls /tmp/reste.txt")).sortie;
  if (!/^\/home\/ada$/m.test(apres) || !/reste\.txt/.test(apres)) throw new Error(`fin du shell : ${fin.propre}\n${apres}`);
  console.log("Ctrl+D sur une ligne vide : « Session terminée ; nouvelle session. », nouvelle invite dans ~, fichiers gardés.");
  vm.fermer();
}

// ---------------------------------------------------------------- énoncés : commandes et sorties annoncées
// Le découpage des commandes est celui de la page : on prend le code de commun/tp.js (une seule source).
const tpjs = readFileSync(path.join(racine, "commun/tp.js"), "utf8");
const commandes = new Function(tpjs.slice(tpjs.indexOf("  function commandes("), tpjs.indexOf("  // Bouton « Copier »")) + "; return commandes;")();
const entites = s => s.replace(/<[^>]*>/g, "").replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
  .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(+d)).replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");

// Les commandes d'un énoncé compilé, dans l'ordre de la page, chacune avec la sortie annoncée juste en dessous.
function lireEnonce(html) {
  const sortie = [];
  for (const [, code] of html.matchAll(/<div class="terminal"><pre><code[^>]*>([\s\S]*?)<\/code><\/pre>/g)) {
    const lignes = entites(code).split("\n");
    const cmds = commandes(lignes);
    cmds.forEach((c, i) => {
      const fin = i + 1 < cmds.length ? lignes.findIndex((l, k) => k > c.fin && /^(\$|# )/.test(l)) : -1;
      const suite = lignes.slice(c.fin + 1, fin < 0 ? undefined : fin);
      const stop = suite.findIndex(l => l.startsWith("# ") || l.startsWith("$ "));
      sortie.push({ commande: c.texte, annonce: (stop < 0 ? suite : suite.slice(0, stop)).join("\n") });
    });
  }
  return sortie;
}
// Sorties comparables : dates, empreintes et chemins personnels neutralisés, espaces de colonnes ramenées à une.
const normaliser = s => s.replace(/\x1b=/g, "").split("\n")
  .filter(l => !/^(remote: )?(Enumerating|Counting|Compressing|Writing|Total|Delta|Resolving|Receiving|Unpacking)/.test(l))
  .map(l => l.replace(/[A-Z][a-z]{2} [ 1-3][0-9] ( [0-9]{4}|[0-9]{2}:[0-9]{2})/g, "<date>").replace(/\b[0-9a-f]{7,40}\b/g, "<h>")
    .replace(/\/(root|home\/ada)\//g, "~/").replace(/\s+/g, " ").trim()).join("\n").trim();

// ---------------------------------------------------------------- ce que chaque TP en mode vm doit montrer
// existe     fichiers de l'état de départ, présents dès l'invite (la VM a lancé le script déclaré par la page)
// sauter     commandes interactives ou qui demandent host-shell-access (non rejouées)
// fixtures   fichiers que l'étudiant écrit à la main (éditeur) : ceux du corrige/, posés dans <dossier> avant la commande
//            qui correspond (la <fois>-ième fois ; sans « avant », avant toutes)
// debut      commandes lancées avant le rejeu (tmux : une session sans client, que l'énoncé ouvre à la main)
// touches    corrige/<kata>.touches rejoué dans Vim après « vim kata.* »
// attendu    [commande, motif de sa sortie] : la dernière exécution de la commande doit le satisfaire
// tolere     commandes qui échouent à dessein (le script « à relire » casse sur un nom à espace)
// ecarts     commandes dont la sortie diffère de l'annonce sans que ce soit un défaut (système de fichiers en
//            mémoire, fichiers de /etc propres à Debian…) : écartées de la comparaison
const corrige = (tp, ...noms) => noms.map(n => path.join(racine, tp, "corrige", n));
const SPECS = {
  "shell/tp/premiers-pas": { existe: ["~/atelier/pionnieres.csv", "~/atelier/.reglages", "~/atelier/journaux/serveur-2026-novembre.log"],
    ecarts: [/^ls -l/, /^cat liste\.txt/, /^type /] },
  "shell/tp/fichiers": { existe: ["~/fichiers/pionnieres.csv", "~/fichiers/coffre", "~/fichiers/scripts/bonjour.sh"],
    ecarts: [/^ls -l?d? /, /^ls -li/, /^find \/etc/, /^cp \/etc/] },
  "shell/tp/scripts": { sauter: [/^shellcheck /], tolere: [/^\.\/a-relire\.sh/], ecarts: [/^bats /],
    attendu: [[/^bats solutions\.bats/, /15 tests, 0 failures/], [/^\.\/a-relire\.sh/, /^Trouvé : rapport\.txt$/m]],
    fixtures: [
      { dossier: "~/tp-scripts", fichiers: corrige("shell/tp/scripts", "liste_fichiers.bash", "copie_fichiers.bash", "copie_fichiers_args.bash",
        "copie_fichiers_robuste.bash", "pipelines.sh", "solutions.bats") },
      { avant: /^\.\/a-relire\.sh/, fois: 2, dossier: "~/tp-scripts", fichiers: corrige("shell/tp/scripts", "a-relire.sh") }] },
  "shell/tp/sed-awk": {},
  "git/tp/git-local": { ecarts: [/^git --version/] },
  "git/tp/git-distant": {},
  "edition-formats/tp/vim": { existe: ["~/dojo/1-survivre/depart.txt", "~/dojo/6-corriger/attendu.txt"], touches: true, sauter: [/^vimtutor/] },
  "acces-distants/tp/tmux": { debut: ["tmux new -d -s atelier"],
    sauter: [/^tmux (new -s|attach|list-panes -s -t atelier -F '#\{window_index\}\.#\{pane_index\} #\{window_name\} #\{pane_current_command\}'$)/, /^kill -KILL/, /^cd \/tmp$/, /^pwd$/],
    fixtures: [{ avant: /^tmux new -d -s essai/, dossier: "~", fichiers: corrige("acces-distants/tp/tmux", "tmux.conf", "session-atelier.sh").map(f => f) }],
    attendu: [[/^tmux show -g base-index/, /^base-index 1$/m], [/^tmux show -gw mode-keys/, /^mode-keys vi$/m], [/^ps -o ppid=/, /^\s*\d+$/m],
      [/^tmux list-windows -t atelier/, /edition[\s\S]*surveillance/]] },
};

// Pages de cours : comme SPECS ; la page annonce chaque sortie (ecarts : celles qu'on ne compare pas).
const SPECS_PAGES = {
  "shell/pages/arbo": { existe: ["~/atelier/pionnieres.csv", "~/atelier/.reglages"] },
  // L'heure : la page en annonce la forme ; le manuel s'affiche dans le pager, sans sortie annoncée.
  "shell/pages/intro": { ecarts: [/^date -u \+%H:%M$/, /^man /], attendu: [[/^date -u \+%H:%M$/, /^\d\d:\d\d$/m]] },
};
// Le modèle du repère de contexte (contexte.js, entre <modele> et </modele>) : une seule source pour la page et le test.
const contextejs = readFileSync(path.join(ici, "contexte.js"), "utf8");
const modele = new Function(contextejs.slice(contextejs.indexOf("// <modele>"), contextejs.indexOf("// </modele>"))
  + "; return { lireRapport, etatsDeclares, lecture };")();
const motsLs = s => normaliser(s).split(/\s+/).filter(Boolean).sort().join(" ");

// Gestes au clavier (page de cours, geste(…) de theme-tp.typ) : les touches, en octets du terminal (xterm).
const TOUCHES = { "Tab": "\t", "Entrée": "\r", "↑": "\x1b[A", "↓": "\x1b[B", "Retour arrière": "\x7f", "Ctrl+A": "\x01",
  "Ctrl+E": "\x05", "Ctrl+←": "\x1b[1;5D", "Ctrl+→": "\x1b[1;5C", "Ctrl+K": "\x0b", "Ctrl+U": "\x15", "Ctrl+Y": "\x19",
  "Ctrl+W": "\x17", "Alt+Retour arrière": "\x1b\x7f", "Ctrl+L": "\x0c", "Ctrl+R": "\x12", "Ctrl+C": "\x03", "Ctrl+D": "\x04" };
function lireGestes(html) {
  return [...html.matchAll(/<div class="geste"([^>]*)>/g)].map(([, a]) => {
    const g = {};
    for (const [, k, v] of a.matchAll(/data-([\w-]+)="([^"]*)"/g)) g[k] = entites(v);
    g.touches = g.touches ? g.touches.split("|") : [];
    return g;
  });
}
// La ligne en cours et le curseur, lus dans Readline par une touche liée à une fonction (Ctrl+X Ctrl+P).
const LIRE_LIGNE = "__cours_ligne() { printf '\\nLIGNE[%s] POINT[%s]\\n' \"$READLINE_LINE\" \"$READLINE_POINT\"; }; bind -x '\"\\C-x\\C-p\": __cours_ligne'";
async function jouerGestes(vm, gestes, echecs) {
  const preparer = async () => { await vm.executer(LIRE_LIGNE); await vm.toucher("history -c\r", vm.INVITE); };
  await preparer();
  const espaces = t => t.replace(/[\b\x07]/g, "").replace(/\s+/g, " ").trim();
  for (const [i, g] of gestes.entries()) {
    const nom = [g.ecrire || g.tape || "", ...g.touches].filter(Boolean).join(" ");
    let vu = "";
    // Le texte d'abord, jusqu'à son écho : les touches qui suivent s'appliquent à la ligne entière, même VM chargée.
    const echo = t => new RegExp(t.slice(-8).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
    if (g.ecrire) vu += (await vm.toucher(g.ecrire, echo(g.ecrire))).propre;
    if (g.tape) vu += (await vm.toucher(g.tape, echo(g.tape))).propre;
    for (const t of g.touches) {
      const entree = t === "Entrée" || (t === "Ctrl+D" && g.touches.at(-1) === "Ctrl+D");
      vu += (await vm.toucher(TOUCHES[t] ?? t, t === g.touches.at(-1) && entree ? vm.INVITE : null)).propre;
    }
    if (g.ecran && !espaces(vu).includes(espaces(g.ecran))) echecs.push(`geste « ${nom} » : l'écran ne montre pas « ${g.ecran} »\n    vu : ${JSON.stringify(espaces(vu).slice(-300))}`);
    if (g.sortie && !espaces(vu).includes(espaces(g.sortie))) echecs.push(`geste « ${nom} » : sortie sans « ${g.sortie} »\n    vu : ${JSON.stringify(espaces(vu).slice(-300))}`);
    if (/nouvelle session/.test(vu)) await preparer();
    // Lire la ligne entre deux Tab romprait la paire « Tab Tab » que le geste suivant achève : on la lit après lui.
    const tabTab = g.touches.at(-1) === "Tab" && gestes[i + 1]?.touches[0] === "Tab";
    if (g.ligne !== undefined && !tabTab) {
      // Une recherche Ctrl+R en cours se termine par Échap (la ligne trouvée reste), avant de lire la ligne.
      if (g.touches.includes("Ctrl+R")) { await vm.toucher("\x1b"); await new Promise(r => setTimeout(r, 700)); }
      const r = (await vm.toucher("\x18\x10", /LIGNE\[[\s\S]*?\] POINT\[\d+\]/)).propre;
      const [, ligne, point] = r.match(/LIGNE\[([\s\S]*?)\] POINT\[(\d+)\]/);
      if (ligne !== g.ligne || point !== g.point) echecs.push(`geste « ${nom} » : ligne « ${ligne} », curseur ${point} ; la page annonce « ${g.ligne} », ${g.point}`);
    }
  }
  return gestes.length;
}

const MOTIFS_ECHEC = /command not found|No such file or directory|not found$|Permission denied$/m;

// Pose des fichiers dans la VM : base64 par morceaux (une ligne de terminal tient 4096 caractères). Les noms
// sont ceux des fichiers : ~/.tmux.conf s'écrit tmux.conf dans le corrige/ ; le nom posé en est dérivé.
async function poser(vm, dossier, fichiers) {
  await vm.executer(`mkdir -p ${dossier}`);
  for (const f of fichiers) {
    const nom = path.basename(f) === "tmux.conf" ? ".tmux.conf" : path.basename(f);
    const b64 = readFileSync(f).toString("base64");
    await vm.executer(`: > /tmp/b64.tmp`);
    for (let i = 0; i < b64.length; i += 1500) await vm.executer(`printf %s '${b64.slice(i, i + 1500)}' >> /tmp/b64.tmp`);
    await vm.executer(`base64 -d /tmp/b64.tmp > ${dossier}/${nom}; rm /tmp/b64.tmp`);
  }
}

async function rejouerTP(tp) {
  const page = /\/pages\//.test(tp);
  const spec = (page ? SPECS_PAGES[tp] : SPECS[tp]) || {};
  const nom = path.basename(tp);
  const tmp = mkdtempSync(path.join(os.tmpdir(), "terminal-tp-"));
  try {
    const html = path.join(tmp, "index.html");
    execFileSync("typst", ["compile", "--root", racine, "--font-path", path.join(racine, "commun/fonts"), "--features", "html",
      "--format", "html", path.join(racine, tp, `${nom}.typ`), html], { stdio: ["ignore", "ignore", "ignore"] });
    const source = readFileSync(html, "utf8");
    // L'état de départ que la page déclare (page-web(depart: …)), installé par la VM avant la première invite.
    const attribut = n => (source.match(new RegExp(`<body[^>]* data-${n}="([^"]*)"`)) || [])[1];
    const etatDepart = { depart: attribut("depart"), ici: attribut("ici") };
    if (!etatDepart.ici) throw new Error("la page ne déclare pas son état de départ (page-web(depart: …))");
    // Les indices (repliés) donnent les commandes à écrire ou à exécuter ; le corrigé les rejoue avec ses sorties.
    // Le rejeu suit l'énoncé sans les indices ; une commande d'indice que le corrigé ne contient pas se rejoue à la fin.
    const INDICE = /<details class="indice">[\s\S]*?<\/details>/g;
    const etapes = lireEnonce(source.replace(INDICE, ""));
    const indices = [...source.matchAll(INDICE)].flatMap(m => lireEnonce(m[0]).map(e => e.commande));
    const gestes = lireGestes(source);
    if (!etapes.length && !gestes.length) throw new Error("aucune commande ni geste trouvé dans l'énoncé");
    const declare = page && source.match(/<script type="application\/json" id="contexte-declare">([\s\S]*?)<\/script>/);
    const etatsPage = declare ? modele.etatsDeclares(JSON.parse(entites(declare[1])), etapes.map(e => e.commande)) : null;
    let rang = 0, contextesVerifies = 0;
    const vm = await demarrerVM(etatDepart);
    // Sans pager : les touches de fin de commande que ce script tape gêneraient less (git log, git config --list).
    await vm.executer("export PAGER=cat GIT_PAGER=cat");
    const echecs = [], sorties = [], derniere = new Map();
    let kata = null;
    const vues = new Map();
    // L'état de départ, avant toute commande : les fichiers attendus sont là.
    if (spec.existe) {
      const t = (await vm.executer(`for f in ${spec.existe.join(" ")}; do test -e "$f" || echo MANQUE:$f; done`)).sortie;
      if (/MANQUE/.test(t)) echecs.push(`état de départ incomplet : ${t.replace(/\n/g, " ")}`);
    }
    for (const c of spec.debut || []) await vm.executer(c);
    for (const f of (spec.fixtures || []).filter(f => !f.avant)) await poser(vm, f.dossier, f.fichiers);
    for (const { commande, annonce } of etapes) {
      for (const f of (spec.fixtures || []).filter(f => f.avant && f.avant.test(commande))) {
        vues.set(f, (vues.get(f) || 0) + 1);
        if (vues.get(f) === (f.fois || 1)) await poser(vm, f.dossier, f.fichiers);
      }
      const m = commande.match(/^cd ~\/dojo\/(\S+)/); if (m) kata = m[1];
      if ((spec.sauter || []).some(r => r.test(commande))) continue;
      let avant = null;
      if (spec.touches && /^vim kata\./.test(commande)) {
        const cles = readFileSync(path.join(racine, tp, "corrige", `${kata}.touches`), "utf8").split("\n").filter(l => !l.startsWith('"')).join("")
          .replace(/<Esc>/g, "\x1b").replace(/<CR>/g, "\r").replace(/<C-v>/g, "\x16").replace(/<C-r>/g, "\x12");
        avant = { quand: /\x1b\[\?1049h/, pause: 1500, envoyer: cles };
      }
      const r = await vm.executer(commande, avant ? 120_000 : 60_000, avant);
      const e = { commande, annonce, sortie: r.sortie, bloque: r.bloque };
      rang++;
      if (page) {
        // Chaque sortie annoncée ; pour ls (sans -l), les mêmes noms, rangés en colonnes selon la largeur du terminal.
        const ls = /^ls(\s+-a)?(\s|$)/.test(commande) && !/^ls -l/.test(commande);
        if (!(spec.ecarts || []).some(x => x.test(commande)) && (ls ? motsLs(r.sortie) !== motsLs(annonce) : normaliser(r.sortie) !== normaliser(annonce)))
          echecs.push(`sortie différente de la page : ${commande}\n    annoncé : ${JSON.stringify(normaliser(annonce))}\n    obtenu  : ${JSON.stringify(normaliser(r.sortie))}`);
        // Le contexte déclaré par la page, après cette commande, contre celui que décrit la VM.
        if (etatsPage) {
          if (!r.contexte) echecs.push(`pas de contexte décrit par la VM après : ${commande}`);
          else {
            const reel = modele.lireRapport(r.contexte), dit = etatsPage[rang];
            if (reel.cwd !== dit.cwd) echecs.push(`contexte : après « ${commande} », la page dit ${dit.cwd}, la VM ${reel.cwd}`);
            for (const [chemin, d] of Object.entries(dit.dossiers)) {
              const v = reel.dossiers[chemin];
              if (d.total == null || !v) continue;
              const a = d.entrees.map(x => x.nom + (x.dossier ? "/" : "")).join(" "), b = v.entrees.map(x => x.nom + (x.dossier ? "/" : "")).join(" ");
              if (a !== b) echecs.push(`contexte : après « ${commande} », ${chemin} contient selon la page « ${a} », selon la VM « ${b} »`);
            }
            contextesVerifies++;
          }
        }
      }
      sorties.push(e); derniere.set(commande.split("\n")[0], e);
      if (r.bloque) echecs.push(`bloquée : ${commande.split("\n")[0]}`);
      else if (MOTIFS_ECHEC.test(r.sortie) && !MOTIFS_ECHEC.test(annonce) && !(spec.tolere || []).some(t => t.test(commande))) echecs.push(`échec inattendu : ${commande.split("\n")[0]} → ${r.sortie.split("\n")[0]}`);
    }
    // Première et dernière commande : la sortie annoncée (comparée sans les écarts connus).
    const comparables = sorties.filter(e => e.annonce && !(spec.ecarts || []).some(r => r.test(e.commande)));
    for (const e of [sorties[0], sorties.at(-1)]) {
      if (!e || !e.annonce || (spec.ecarts || []).some(r => r.test(e.commande))) continue;
      if (normaliser(e.sortie) !== normaliser(e.annonce)) echecs.push(`sortie différente de l'annonce : ${e.commande.split("\n")[0]}\n    annoncé : ${JSON.stringify(normaliser(e.annonce).slice(0, 200))}\n    obtenu  : ${JSON.stringify(normaliser(e.sortie).slice(0, 200))}`);
    }
    for (const [cmd, motif] of spec.attendu || []) {
      const e = [...derniere].reverse().find(([c]) => cmd.test(c));
      if (!e) echecs.push(`commande attendue absente : ${cmd}`);
      else if (!motif.test(e[1].sortie)) echecs.push(`${e[0]} : sortie sans ${motif} :\n${e[1].sortie.slice(-300)}`);
    }
    if (spec.touches) {
      const reussis = sorties.filter(e => /^diff -u attendu/.test(e.commande) && /^réussi$/m.test(e.sortie)).length;
      if (reussis !== 6) echecs.push(`katas réussis : ${reussis} sur 6`);
    }
    const gestesJoues = gestes.length ? await jouerGestes(vm, gestes, echecs) : 0;
    const rejouees = new Set(etapes.map(e => e.commande));
    let indicesSeuls = 0;
    for (const commande of [...new Set(indices)].filter(c => !rejouees.has(c))) {
      const r = await vm.executer(commande);
      indicesSeuls++;
      if (r.bloque) echecs.push(`bloquée (indice) : ${commande}`);
      else if (MOTIFS_ECHEC.test(r.sortie) && !(spec.tolere || []).some(t => t.test(commande))) echecs.push(`échec (indice) : ${commande} → ${r.sortie.split("\n")[0]}`);
    }
    vm.fermer();
    // Page de cours : chaque section qui suppose l'état de départ tel quel (le contexte déclaré avant sa première commande
    // est celui de l'arrivée) se rejoue seule, dans une VM neuve, sans les commandes qui la précèdent.
    let sectionsSeules = 0;
    if (page && etatsPage) {
      const sections = source.split(/<h2[ >]/).slice(1).map(lireEnonce).filter(c => c.length);
      const empreinte = e => JSON.stringify([e.cwd, e.dossiers]);
      let debut = 0;
      for (const cmds of sections) {
        const i = debut; debut += cmds.length;
        if (i === 0 || empreinte(etatsPage[i]) !== empreinte(etatsPage[0])) continue;
        const vm2 = await demarrerVM(etatDepart);
        await vm2.executer("export PAGER=cat GIT_PAGER=cat");
        for (const { commande, annonce } of cmds) {
          const r = await vm2.executer(commande);
          const ls = /^ls(\s+-a)?(\s|$)/.test(commande);
          if (ls ? motsLs(r.sortie) !== motsLs(annonce) : normaliser(r.sortie) !== normaliser(annonce))
            echecs.push(`section rejouée seule, VM neuve : ${commande}\n    annoncé : ${JSON.stringify(normaliser(annonce))}\n    obtenu  : ${JSON.stringify(normaliser(r.sortie))}`);
        }
        vm2.fermer(); sectionsSeules++;
      }
    }
    const lignes = page ? `${sorties.length} commandes rejouées, chaque sortie comparée à la page, contexte comparé après ${contextesVerifies} commandes, ${sectionsSeules} sections rejouées seules dans une VM neuve` + (gestesJoues ? `, ${gestesJoues} gestes joués touche par touche (ligne, curseur, écran, sortie)` : "")
      : `${sorties.length} commandes rejouées, 1re et dernière comparées à l'énoncé` + (indices.length ? `, ${indices.length} commandes d'indices (${indicesSeuls} hors corrigé, rejouées à la fin)` : "");
    return { tp, secondes: vm.secondes, resume: lignes, echecs, comparables: comparables.length };
  } finally { rmSync(tmp, { recursive: true, force: true }); }
}

// ---------------------------------------------------------------- TP et pages de cours en mode vm : leur source le déclare
function enModeVm(nature) {
  const sortie = [];
  for (const cours of readdirSync(racine)) {
    const dossier = path.join(racine, cours, nature);
    if (!existsSync(dossier)) continue;
    for (const tp of readdirSync(dossier)) {
      const source = path.join(dossier, tp, `${tp}.typ`);
      if (existsSync(source) && /terminal: *\([^)]*"vm"/.test(readFileSync(source, "utf8"))) sortie.push(`${cours}/${nature}/${tp}`);
    }
  }
  return sortie;
}

// ---------------------------------------------------------------- programme principal
const argument = process.argv[2];
if (argument === "--tp") {
  const r = await rejouerTP(process.argv[3]);
  console.log(`${r.echecs.length ? "ÉCHEC" : "ok"} - ${r.tp} : VM prête en ${r.secondes} s, ${r.resume}`);
  for (const e of r.echecs) console.log("  " + e);
  process.exit(r.echecs.length ? 1 : 0);
} else {
  const outils = process.argv.slice(2).length ? process.argv.slice(2)
    : ["bash", "git", "vim", "vimtutor", "nano", "tmux", "jq", "gawk", "sed", "less", "tree", "tar", "find", "xargs", "bats", "man", "ps", "wget", "curl"];
  await testerImage(outils);
  if (process.argv.slice(2).length) process.exit(0);
  // Le rejeu des TP : un processus par TP (la VM de v86 est monothread), quatre à la fois.
  const tps = enModeVm("tp"), pages = enModeVm("pages");
  const manquants = Object.keys(SPECS).filter(t => !tps.includes(t));
  if (manquants.length) { console.error(`SPECS cite des TP qui ne déclarent pas le mode vm : ${manquants.join(", ")}`); process.exit(1); }
  const sansSpec = tps.filter(t => !(t in SPECS));
  if (sansSpec.length) { console.error(`TP en mode vm sans entrée dans SPECS (tester-vm.mjs) : ${sansSpec.join(", ")}`); process.exit(1); }
  const file = [...pages, ...tps];
  let echecs = 0;
  const lancer = tp => new Promise(fini => {
    let texte = "";
    const p = spawn(process.execPath, [import.meta.filename, "--tp", tp]);
    p.stdout.on("data", d => { texte += d; }); p.stderr.on("data", d => { texte += d; });
    p.on("close", code => { process.stdout.write(texte); if (code) echecs++; fini(); });
  });
  const attente = [...file];
  await Promise.all(Array.from({ length: 4 }, async () => { for (let tp; (tp = attente.shift());) await lancer(tp); }));
  if (echecs) { console.error(`${echecs} TP ou pages en échec`); process.exit(1); }
  console.log(`${tps.length} TP et ${pages.length} page(s) de cours en mode vm rejoués dans la VM.`);
  process.exit(0);
}
