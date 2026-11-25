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
const serveur = port => enfants.push(spawn("python3", ["-I", "-m", "http.server", String(port), "--bind", "127.0.0.1",
  "--directory", depot], { stdio: "ignore" }));
function compagnon() {
  const p = spawn("python3", ["-I", path.join(__dirname, "iadmin-terminal.py"), "local", "--shell", "/bin/bash"],
    { cwd: temporaire, env: { ...process.env, HOME: temporaire } });
  enfants.push(p);
  p.erreurs = ""; p.stderr.on("data", d => { p.erreurs += d; });
  p.fini = new Promise(r => p.on("exit", r));
  return new Promise(r => { let tampon = ""; p.stdout.on("data", d => { tampon += d; const m = tampon.match(/ws:\/\/\S+/); if (m) r({ p, url: m[0] }); }); });
}
const attendre = ms => new Promise(r => setTimeout(r, ms));
const ecran = page => page.locator(".terminal-ecran:not([hidden]) .xterm-rows");
const etat = page => page.locator(".terminal-etat");
const executer = (page, debut) => page.locator(".terminal .executer").filter({ has: page.locator("xpath=..") })
  .and(page.locator(`xpath=//button[contains(@class,'executer')][starts-with(@data-commande, ${JSON.stringify(debut)})]`)).first();
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
  await ecran(page).filter({ hasText: `Bonjour depuis ${os.hostname()}` }).waitFor({ timeout: 10000 });
  ok(`compagnon : commande exécutée dans le vrai shell, sortie affichée en ${Date.now() - t0} ms`);
  await page.click(".terminal-actions button");
  await p.fini;
  ok("compagnon : « Déconnecter » arrête le compagnon");

  // 3. TP réels : wordpress (commande sur deux lignes, suite par \), libvirt.
  for (const [nom, debut, attendu] of [
    ["wordpress", "docker container exec mon_conteneur_wordpress", /No such container|command not found|Cannot connect/],
    ["libvirt", "virsh uri", /virsh: command not found|qemu:\/\/\//],
  ]) {
    ({ p, url } = await compagnon());
    await page.goto(adresse(nom));
    await connecter(page, url);
    await etat(page).filter({ hasText: "Connecté" }).waitFor({ timeout: 10000 });
    await executer(page, debut).click();
    await ecran(page).filter({ hasText: attendu }).waitFor({ timeout: 10000 });
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
  await executer(page, "printf 'a;1").click();
  verifier(/Démarrez d’abord/.test(await etat(page).innerText()), "VM : avant le démarrage, « Exécuter » invite à démarrer");
  t0 = Date.now();
  await page.locator(".terminal-accueil button.principal", { hasText: "Démarrer" }).click();
  await executer(page, "printf 'a;1").click();
  verifier(/en attente/.test(await etat(page).innerText()), "VM : commande cliquée pendant le téléchargement, mise en attente");
  await etat(page).filter({ hasText: "VM prête" }).waitFor({ timeout: 180000 });
  const froid = Date.now() - t0;
  const telecharges = vmFichiers.length;
  ok(`VM, premier démarrage : prête en ${(froid / 1000).toFixed(1)} s, ${telecharges} fichiers téléchargés`);
  for (const [debut, attendu] of [["awk", "Total : 3"], ["sed", "A;1"], ["git init", /^1$/m], ["printf 'été", /^2$/m], ["echo un", "un deux"]]) {
    const avant = Date.now();
    await executer(page, debut).click();
    await ecran(page).filter({ hasText: attendu }).waitFor({ timeout: 30000 });
    ok(`VM : « ${debut} » → ${attendu} (${Date.now() - avant} ms)`);
  }
  const lignes = (await ecran(page).innerText()).split("\n").filter(l => l.includes("printf 'a;1"));
  verifier(lignes.length === 1, "VM : la commande mise en attente s’affiche une seule fois");
  await page.selectOption("#variante", "achromatopsie");
  await attendre(200);
  const fonds = await page.evaluate(() => [getComputedStyle(document.querySelector(".terminal-ecran:not([hidden]) .xterm-viewport")).backgroundColor,
    getComputedStyle(document.documentElement).getPropertyValue("--c-nuit").trim()]);
  ok(`VM : le terminal suit la variante (fond ${fonds[0]}, --c-nuit ${fonds[1]})`);
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
  await ecran(page).filter({ hasText: "Total : 3" }).waitFor({ timeout: 30000 });
  ok("VM, deuxième visite : commandes exécutées");
  await contexte.close();

  console.log(`\n${reussis.length} vérifications réussies ; captures dans ${captures}`);
})().catch(e => { console.error(e); process.exitCode = 1; }).finally(() => {
  for (const e of enfants) e.kill();
  fs.rmSync(temporaire, { recursive: true, force: true });
});
