// tester-navigateur.js — vérifie le terminal des pages web dans Chromium (Playwright), sur des pages compilées
// à leur place et servies en local. Usage, depuis la racine du dépôt, après commun/terminal/preparer.sh --vm :
//   node commun/terminal/tester-navigateur.js [dossier des captures]
// Compile les pages testées, dont une page d’essai du mode VM dans build/essai-terminal/, lance deux serveurs
// (localhost:8000, origine admise par le compagnon ; localhost:8001, origine refusée) et des compagnons.
const { chromium } = require("playwright");
const { spawn, execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const depot = path.resolve(__dirname, "../..");
const captures = path.resolve(process.argv[2] || path.join(depot, "build/essai-terminal/captures"));
const temporaire = fs.mkdtempSync(path.join(os.tmpdir(), "terminal-"));
const reussis = [];
const ok = texte => { reussis.push(texte); console.log("ok -", texte); };
const verifier = (condition, texte) => { if (!condition) throw new Error("échec : " + texte); ok(texte); };

// ---------- Pages ----------
const essai = `#import "../../commun/theme-tp.typ": *
#show: page-web.with(titre: [Essai du terminal], surtitre: [Page d’essai (build/)], racine: "../../",
  terminal: ("vm", "compagnon"))
= Commandes <commandes>
#terminal[\`\`\`console
$ printf 'a;1\\nb;2\\n' > t.csv
$ awk -F';' '{ s += $2 } END { print "Total :", s }' t.csv
$ sed 's/a/A/' t.csv
# un commentaire
$ git init -q depot && git -C depot -c user.name=E -c user.email=e@x commit -q --allow-empty -m init && git -C depot log --oneline | wc -l
$ printf 'été\\n' | wc -m
$ echo un \\
    deux
\`\`\`]
`;
fs.mkdirSync(path.join(depot, "build/essai-terminal"), { recursive: true });
fs.writeFileSync(path.join(depot, "build/essai-terminal/essai.typ"), essai);
const pages = {
  essai: "build/essai-terminal/essai.typ", compagnon: "commun/terminal/compagnon.typ",
  wordpress: "conteneurisation/tp/wordpress/wordpress.typ", libvirt: "virtualisation/tp/libvirt/libvirt.typ",
  accueil: "index.typ", artefact: "conteneurisation/artefacts/cache-de-build/cache-de-build.typ",
  // Les TP en mode vm (le rejeu complet de leurs commandes est dans tester-vm.mjs).
  "tp-premiers-pas": "shell/tp/premiers-pas/premiers-pas.typ", "tp-fichiers": "shell/tp/fichiers/fichiers.typ",
  "tp-scripts": "shell/tp/scripts/scripts.typ", "tp-sed-awk": "shell/tp/sed-awk/sed-awk.typ",
  "tp-git-local": "git/tp/git-local/git-local.typ", "tp-git-distant": "git/tp/git-distant/git-distant.typ",
  "tp-vim": "edition-formats/tp/vim/vim.typ", "tp-tmux": "acces-distants/tp/tmux/tmux.typ",
  // Une page de cours : terminal à côté du texte, repère de contexte (le rejeu complet est dans tester-vm.mjs).
  "cours-arbo": "shell/pages/arbo/arbo.typ",
};
const html = {};
for (const [nom, source] of Object.entries(pages)) {
  html[nom] = path.join(path.dirname(source), "index.html");
  execFileSync("typst", ["compile", "--root", ".", "--font-path", "commun/fonts", "--features", "html", "--format", "html",
    source, html[nom]], { cwd: depot, stdio: ["ignore", "ignore", "inherit"] });
}
const adresse = (nom, port = 8000) => `http://localhost:${port}/${html[nom]}`;

// ---------- Serveurs et compagnon ----------
const enfants = [];
const arch = { x64: "amd64", arm64: "arm64" }[process.arch];
const binaire = path.join(__dirname, `compagnon/dist/iadmin-terminal-linux-${arch}`);
const serveur = port => enfants.push(spawn("python3", ["-I", "-m", "http.server", String(port), "--bind", "127.0.0.1",
  "--directory", depot], { stdio: "ignore" }));
function compagnon() {
  const p = spawn(binaire, ["local", "--shell", "/bin/bash"],
    { cwd: temporaire, env: { ...process.env, HOME: temporaire } });
  enfants.push(p);
  p.erreurs = ""; p.stderr.on("data", d => { p.erreurs += d; });
  p.fini = new Promise(r => p.on("exit", r));
  return new Promise(r => { let tampon = ""; p.stdout.on("data", d => { tampon += d; const m = tampon.match(/ws:\/\/\S+/); if (m) r({ p, url: m[0] }); }); });
}
const attendre = ms => new Promise(r => setTimeout(r, ms));
const ecran = page => page.locator(".terminal-ecran:not([hidden]) .xterm-rows");
const etat = page => page.locator(".terminal-etat");
// Attend un motif dans le texte affiché par le terminal, ligne par ligne (innerText).
async function attendreTexte(page, motif, delai = 30000) {
  const fin = Date.now() + delai;
  for (;;) {
    const texte = await ecran(page).innerText().catch(() => "");
    if (typeof motif === "string" ? texte.includes(motif) : motif.test(texte)) return texte;
    if (Date.now() > fin) throw new Error(`motif ${motif} absent du terminal :\n${texte}`);
    await attendre(100);
  }
}
const executer = (page, debut) => page.locator(`.terminal .executer[data-commande^=${JSON.stringify(debut)}]`).first();
async function connecter(page, url) {
  await page.click(".terminal-lanceur");
  await page.fill(".terminal-appairage input", url);
  await page.click(".terminal-appairage button");
}

(async () => {
  serveur(8000); serveur(8001);
  await attendre(800);
  fs.mkdirSync(captures, { recursive: true });
  const profil = path.join(temporaire, "profil");
  let contexte = await chromium.launchPersistentContext(profil, { viewport: { width: 1280, height: 800 } });
  let page = contexte.pages()[0] || await contexte.newPage();
  page.on("pageerror", e => console.error("erreur de page :", e.message));

  // 1. Pages sans terminal : ni bouton « Exécuter », ni volet.
  for (const nom of ["accueil", "artefact"]) {
    await page.goto(adresse(nom));
    const r = await page.evaluate(() => [document.querySelectorAll(".executer, .terminal-lanceur, .terminal-volet").length,
      document.body.dataset.terminal ?? null, document.querySelectorAll(".copier").length]);
    verifier(r[0] === 0 && r[1] === null, `${nom} : page sans terminal, ni « Exécuter » ni volet (${r[2]} boutons Copier)`);
  }

  // 2. Compagnon : connexion, commande cliquée, sortie dans la page.
  let { p, url } = await compagnon();
  await page.goto(adresse("compagnon"));
  verifier(await page.locator(".executer[aria-disabled='true']").count() > 0, "compagnon : « Exécuter » inactif tant que rien n’est connecté");
  await connecter(page, url);
  await etat(page).filter({ hasText: "Connecté" }).waitFor({ timeout: 10000 });
  verifier(await page.locator(".executer[aria-disabled='true']").count() === 0, "compagnon : « Exécuter » actif une fois connecté");
  let t0 = Date.now();
  await executer(page, "echo \"Bonjour").click();
  await attendreTexte(page, `Bonjour depuis ${os.hostname()}`, 15000);
  ok(`compagnon : commande exécutée dans le vrai shell, sortie affichée en ${Date.now() - t0} ms`);
  await page.click(".terminal-actions button");
  await p.fini;
  ok("compagnon : « Déconnecter » arrête le compagnon");

  // 3. TP réels : wordpress (commande sur deux lignes, suite par \), libvirt.
  for (const [nom, debut, attendu] of [
    ["wordpress", "docker container exec mon_conteneur_wordpress", /No such container|command not found|Cannot connect/],
    ["libvirt", "virsh uri", /virsh: command not found|qemu:\/\/\/|failed to connect to the hypervisor/],
  ]) {
    ({ p, url } = await compagnon());
    await page.goto(adresse(nom));
    await connecter(page, url);
    await etat(page).filter({ hasText: "Connecté" }).waitFor({ timeout: 10000 });
    // La commande peut être dans un indice ou un corrigé replié : on l’ouvre, comme le lecteur.
    await executer(page, debut).evaluate(b => { for (let d = b.closest("details"); d; d = d.parentElement.closest("details")) d.open = true; });
    await executer(page, debut).click();
    await attendreTexte(page, attendu, 15000);
    ok(`${nom} : « ${debut} » exécutée, sortie ${attendu}`);
    for (const [largeur, hauteur] of [[1280, 650], [1920, 950]]) {
      await page.setViewportSize({ width: largeur, height: hauteur });
      await attendre(300);
      await page.evaluate(() => scrollTo(0, document.documentElement.scrollHeight));
      await attendre(300);
      const m = await page.evaluate(() => {
        const v = document.querySelector(".terminal-volet").getBoundingClientRect();
        const pied = document.querySelector(".pied").getBoundingClientRect();
        const toc = document.querySelector('nav[role="doc-toc"]').getBoundingClientRect();
        const colonne = getComputedStyle(document.querySelector('nav[role="doc-toc"]')).position === "sticky";
        return { haut: v.top, hauteur: v.height, pied: pied.bottom, toc: colonne ? toc.bottom : 0 };
      });
      verifier(m.pied <= m.haut + 1 && m.toc <= m.haut + 1 && m.hauteur <= hauteur * 0.41,
        `${nom} ${largeur} × ${hauteur} : volet de ${Math.round(m.hauteur)} px, fin de page et sommaire au-dessus`);
      await page.evaluate(() => scrollTo(0, 0));
      await page.screenshot({ path: path.join(captures, `${nom}-${largeur}x${hauteur}.png`) });
    }
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.click(".terminal-actions button");
    await p.fini;
  }

  // 4. Refus : mauvais jeton, origine non admise, adresse hors de la machine.
  ({ p, url } = await compagnon());
  await page.goto(adresse("compagnon"));
  await connecter(page, url.replace(/token=.*/, "token=faux"));
  await etat(page).filter({ hasText: "Connexion impossible" }).waitFor({ timeout: 10000 });
  await p.fini;
  verifier(/401/.test(p.erreurs), "mauvais jeton : refus 401, compagnon arrêté, la page dit « Connexion impossible »");
  ({ p, url } = await compagnon());
  await page.goto(adresse("compagnon", 8001));
  await connecter(page, url);
  await etat(page).filter({ hasText: "Connexion impossible" }).waitFor({ timeout: 10000 });
  await p.fini;
  verifier(/403/.test(p.erreurs), "origine non admise (localhost:8001) : refus 403, compagnon arrêté");
  await page.goto(adresse("compagnon"));
  await connecter(page, "ws://192.0.2.7:1234/?token=abc");
  verifier(/Adresse refusée/.test(await etat(page).innerText()), "adresse hors de la machine : refusée par la page");

  // 5. VM : premier démarrage (téléchargement, mise en cache), commandes en attente puis exécutées.
  const vmFichiers = [];
  const suivreReseau = pg => pg.on("response", r => { if (/\/vendor\/(vm\/(bzImage|initrd\.gz)|v86\.wasm|libv86\.js|\w+bios\.bin)$/.test(r.url())) vmFichiers.push(r.url()); });
  suivreReseau(page);
  await page.goto(adresse("essai"));
  await page.evaluate(() => caches.keys().then(k => Promise.all(k.map(n => caches.delete(n)))));
  await page.reload();
  await page.click(".terminal-lanceur");
  await page.locator(".terminal-modes button", { hasText: "VM" }).click();
  await page.locator(".terminal-accueil:not([hidden])").filter({ hasText: "à télécharger" }).waitFor();
  await executer(page, "printf 'a;1").click({ force: true }); // aria-disabled : Playwright le croit inactif
  verifier(/Démarrez d’abord/.test(await etat(page).innerText()), "VM : avant le démarrage, « Exécuter » invite à démarrer");
  t0 = Date.now();
  await page.locator(".terminal-accueil button.principal", { hasText: "Démarrer" }).click();
  await executer(page, "printf 'a;1").click();
  verifier(/en attente/.test(await etat(page).innerText()), "VM : commande cliquée pendant le téléchargement, mise en attente");
  await etat(page).filter({ hasText: "VM prête" }).waitFor({ timeout: 180000 });
  const froid = Date.now() - t0;
  const telecharges = vmFichiers.length;
  ok(`VM, premier démarrage : prête en ${(froid / 1000).toFixed(1)} s, ${telecharges} fichiers téléchargés`);
  // Avant les autres commandes, tant que la ligne est encore à l’écran : elle y figure une fois (pas d’écho double).
  await attendreTexte(page, "printf 'a;1"); await attendre(500);
  const lignes = (await ecran(page).innerText()).split("\n").filter(l => l.includes("printf 'a;1"));
  verifier(lignes.length === 1, "VM : la commande mise en attente s’affiche une seule fois");
  for (const [debut, attendu] of [["awk", "Total : 3"], ["sed", "A;1"], ["git init", /^1$/m], ["printf 'été", /^4$/m] /* 3 lettres et la fin de ligne : l’UTF-8 passe */, ["echo un", "un deux"]]) {
    const avant = Date.now();
    await executer(page, debut).click();
    await attendreTexte(page, attendu);
    ok(`VM : « ${debut} » → ${attendu} (${Date.now() - avant} ms)`);
  }
  await page.selectOption("#variante", "achromatopsie");
  await attendre(200);
  const fonds = await page.evaluate(() => [getComputedStyle(document.querySelector(".terminal-ecran:not([hidden]) .xterm-viewport")).backgroundColor,
    getComputedStyle(document.documentElement).getPropertyValue("--c-nuit").trim()]);
  const hex = c => "#" + c.match(/\d+/g).slice(0, 3).map(n => (+n).toString(16).padStart(2, "0")).join("");
  verifier(hex(fonds[0]) === fonds[1].toLowerCase(), `VM : le fond du terminal est celui de la charte en achromatopsie (${fonds[0]}, --c-nuit ${fonds[1]})`);
  await page.selectOption("#variante", "projection");
  for (const [largeur, hauteur] of [[1280, 650], [1920, 950]]) {
    await page.setViewportSize({ width: largeur, height: hauteur });
    await attendre(400);
    await page.screenshot({ path: path.join(captures, `vm-${largeur}x${hauteur}.png`) });
  }
  await contexte.close();

  // 6. Deuxième visite, navigateur relancé : l’image vient du cache, rien n’est retéléchargé.
  vmFichiers.length = 0;
  contexte = await chromium.launchPersistentContext(profil, { viewport: { width: 1280, height: 800 } });
  page = contexte.pages()[0] || await contexte.newPage();
  const reseau = [];
  page.on("request", r => { if (r.url().includes("/vendor/")) reseau.push(r.url().replace(/.*\/vendor\//, "")); });
  await page.goto(adresse("essai"));
  await page.click(".terminal-lanceur");
  await page.locator(".terminal-accueil:not([hidden])").filter({ hasText: "déjà dans le cache" }).waitFor();
  t0 = Date.now();
  await page.locator(".terminal-accueil button.principal", { hasText: "Démarrer" }).click();
  await etat(page).filter({ hasText: "VM prête" }).waitFor({ timeout: 180000 });
  const chaud = Date.now() - t0;
  const image = reseau.filter(u => /^(vm\/(bzImage|initrd\.gz)|v86\.wasm|libv86\.js|\w+bios\.bin)$/.test(u));
  verifier(image.length === 0, `VM, deuxième visite : prête en ${(chaud / 1000).toFixed(1)} s, aucune requête pour l’image (requêtes : ${reseau.join(", ")})`);
  await executer(page, "printf 'a;1").click();
  await executer(page, "awk").click();
  await attendreTexte(page, "Total : 3");
  ok("VM, deuxième visite : commandes exécutées");

  // 7. TP en mode vm : la page propose le terminal et un « Exécuter » par commande ; sur deux TP, les clics de la
  // première étape (téléchargement sans réseau, script de départ) posent les fichiers de départ, sous le compte ada.
  for (const nom of Object.keys(pages).filter(n => n.startsWith("tp-"))) {
    await page.goto(adresse(nom));
    const r = await page.evaluate(() => [document.body.dataset.terminal, document.querySelectorAll(".terminal .executer").length,
      document.querySelector(".terminal-lanceur") !== null]);
    verifier(r[0] === "vm compagnon" && r[1] > 0 && r[2], `${nom} : terminal « vm compagnon », ${r[1]} boutons « Exécuter »`);
  }
  for (const [nom, clics, attendu] of [
    ["tp-premiers-pas", ["wget ", "bash preparer.sh", "whoami"], "Dossier de travail prêt : /home/ada/atelier"],
    ["tp-vim", ["curl ", "ls dojo"], "1-survivre"],
  ]) {
    await page.goto(adresse(nom));
    await page.click(".terminal-lanceur");
    await page.locator(".terminal-accueil button.principal", { hasText: "Démarrer" }).click();
    for (const debut of clics) {   // une commande peut être dans un corrigé replié : on l'ouvre, comme le lecteur
      await executer(page, debut).evaluate(b => { for (let d = b.closest("details"); d; d = d.parentElement.closest("details")) d.open = true; });
      await executer(page, debut).click();
    }
    await attendreTexte(page, attendu, 120000);
    ok(`${nom} : « ${clics.join(" », « ")} » cliqués dans la VM, fichiers de départ présents (${attendu})`);
  }

  // 8. Page de cours : sur un écran large, le terminal est dans la colonne de droite, ouvert d’emblée, sous le repère
  // de contexte ; le repère est déclaré par la page, puis lu dans la VM ; un cd cliqué y est tracé pas à pas.
  await page.setViewportSize({ width: 1280, height: 650 });
  await page.goto(adresse("cours-arbo"));
  const repere = () => page.evaluate(() => {
    const c = document.querySelector(".contexte"), v = document.querySelector(".terminal-volet");
    return { source: c.dataset.source, cwd: c.dataset.cwd, ici: c.querySelector(".nom.ici")?.textContent,
      pastilles: c.querySelectorAll(".arbre .pastille").length, dansCote: Boolean(v.closest(".cote")), ouvert: !v.hidden,
      position: getComputedStyle(v).position, droite: v.getBoundingClientRect().left > innerWidth / 2,
      defile: document.documentElement.scrollWidth > innerWidth };
  });
  let r = await repere();
  verifier(r.dansCote && r.ouvert && r.position === "static" && r.droite && !r.defile && r.source === "page" && r.cwd === "/home/ada",
    "page de cours 1280 × 650 : terminal ouvert à droite du texte, sous le repère, déclaré par la page (/home/ada)");
  await page.locator(".terminal-accueil button.principal", { hasText: "Démarrer" }).click();
  await etat(page).filter({ hasText: "VM prête" }).waitFor({ timeout: 180000 });
  for (const debut of ["wget ", "bash preparer.sh", "cd atelier", "cd notes", "cd ../projets/site"]) {
    await executer(page, debut).scrollIntoViewIfNeeded();
    await executer(page, debut).click();
    await attendreTexte(page, debut.startsWith("cd ../") ? "~/atelier/projets/site$" : debut.startsWith("bash") ? "Dossier de travail" : debut, 120000);
  }
  await attendre(2500);   // le tracé (une pastille toutes les 0,45 s), puis l’état qui suit
  r = await repere();
  verifier(r.source === "vm" && r.cwd === "/home/ada/atelier/projets/site" && r.ici === "site/" && r.pastilles === 3,
    `page de cours : repère lu dans la VM après « cd ../projets/site » (${r.cwd}, « vous êtes ici » sur ${r.ici}, ${r.pastilles} pastilles)`);
  await page.screenshot({ path: path.join(captures, "cours-arbo-1280x650.png") });
  await page.setViewportSize({ width: 390, height: 800 });
  await attendre(400);
  r = await repere();
  verifier(r.position === "fixed" && !r.defile, "page de cours 390 px : le terminal redevient un volet en bas, sans défilement horizontal");
  await contexte.close();

  console.log(`\n${reussis.length} vérifications réussies ; captures dans ${captures}`);
})().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  for (const e of enfants) e.kill();
  try { fs.rmSync(temporaire, { recursive: true, force: true, maxRetries: 3 }); } catch { /* profil encore ouvert */ }
  process.exit();
});
