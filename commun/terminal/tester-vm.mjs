// tester-vm.mjs — démarre l'image de la VM dans Node (v86 de vendor/), attend l'invite, exécute une commande
// par le port série, comme la page, et vérifie sa sortie. Usage, après preparer.sh --vm :
//   node commun/terminal/tester-vm.mjs [outil …]      (par défaut : les outils de construire-vm.sh)
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import path from "node:path";

const vendor = path.join(import.meta.dirname, "vendor");
const { V86 } = createRequire(import.meta.url)(path.join(vendor, "libv86.js"));
const manifeste = JSON.parse(readFileSync(path.join(vendor, "vm/manifeste.json"), "utf8"));
const lire = f => { const b = readFileSync(path.join(vendor, f)); return b.buffer.slice(b.byteOffset, b.byteOffset + b.length); };
const outils = process.argv.slice(2).length ? process.argv.slice(2) : ["bash", "git", "vim", "nano", "tmux", "jq", "gawk", "sed", "less", "tree"];

const debut = Date.now();
const secondes = () => ((Date.now() - debut) / 1000).toFixed(1);
const vm = new V86({
  wasm_fn: async env => (await WebAssembly.instantiate(lire("v86.wasm"), env)).instance.exports,
  bios: { buffer: lire("seabios.bin") }, vga_bios: { buffer: lire("vgabios.bin") },
  bzimage: { buffer: lire("vm/bzImage") }, initrd: { buffer: lire("vm/initrd.gz") },
  cmdline: "console=ttyS0,115200 rdinit=/init terminal=100x30",
  memory_size: manifeste.memoire_mo * 1024 * 1024, autostart: true, disable_keyboard: true, disable_mouse: true,
});
let sortie = "", etape = "demarrage";
const echec = raison => { console.error(`Échec (${raison}) après ${secondes()} s. Fin de la console :\n${sortie.slice(-1500)}`); process.exit(1); };
const minuteur = setTimeout(() => echec("délai dépassé"), 240_000);
vm.add_listener("serial0-output-byte", octet => {
  sortie += String.fromCharCode(octet);
  if (etape === "demarrage" && sortie.includes("\x1b]0;cours-terminal-pret\x07")) {
    etape = "marqueur";
  } else if (etape === "marqueur" && /[$#] $/.test(sortie)) {
    etape = "commande";
    console.log(`Invite après ${secondes()} s (${manifeste.version}).`);
    vm.serial0_send(`echo DEBUT_$((6*7)); for c in ${outils.join(" ")}; do command -v $c >/dev/null || echo ABSENT:$c; done; stty size; echo FIN_$((6*7))\r`);
  } else if (etape === "commande" && sortie.includes("FIN_42")) {
    clearTimeout(minuteur);
    const resultat = sortie.slice(sortie.indexOf("DEBUT_42"));
    const absents = [...resultat.matchAll(/ABSENT:(\S+)/g)].map(m => m[1]);
    const taille = resultat.match(/\n(\d+ \d+)\r?\n/)?.[1];
    if (absents.length) echec(`outils absents : ${absents.join(", ")}`);
    if (taille !== "30 100") echec(`taille du terminal ${taille}, attendue 30 100`);
    console.log(`Commande exécutée après ${secondes()} s : ${outils.length} outils présents, terminal 100 × 30.`);
    vm.destroy();
    process.exit(0);
  }
});
