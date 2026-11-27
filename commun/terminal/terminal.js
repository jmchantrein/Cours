// terminal.js — le terminal des pages web, ajouté par theme-tp.typ aux pages qui déclarent
// page-web(terminal: …). Un clic sur « Exécuter » (bouton posé par tp.js sur chaque commande) envoie la
// commande au terminal ouvert, où elle s’exécute. Deux modes :
// - "vm" : une VM Linux dans le navigateur (v86), sans réseau ; l’image se télécharge au premier démarrage,
//   puis se range dans Cache Storage sous une clé qui porte sa version ;
// - "compagnon" : le vrai shell de l’étudiant, par l’exécutable iadmin-terminal (compagnon/, WebSocket sur 127.0.0.1, jeton).
// Les fichiers tiers (xterm.js, v86, image) sont dans vendor/, construit par preparer.sh, chargés à la demande.
// Sur une page de cours (page-web(cours: true)), le terminal se place dans la colonne `.cote`, à côté du texte ; il est
// ouvert d’emblée sur un écran large. Événements, pour le repère de contexte (contexte.js) et tp.js :
// « terminal-commande » (une commande cliquée part dans le terminal), « terminal-session » (une session s’ouvre ou se
// ferme), « terminal-contexte » (le shell de la VM a décrit où il est : séquence OSC 6973, voir vm/contexte.bash).
(() => {
  const modes = (document.body.dataset.terminal || "").split(" ").filter(m => m === "vm" || m === "compagnon");
  const bandeau = document.querySelector(".bandeau");
  if (!modes.length || !bandeau) return;
  const racine = document.body.dataset.racine || "";
  const vendor = racine + "commun/terminal/vendor/";
  const guide = racine + "commun/terminal/index.html";
  const PREFIXE_CACHE = "cours-terminal-vm-";
  const NOMS = { vm: "VM dans le navigateur", compagnon: "Mon shell (compagnon)" };
  // L’état de départ de la page (page-web(depart: …)) : un script versionné du dépôt, ce qu’il crée, le répertoire
  // d’arrivée. La VM le lance à son démarrage ; le compagnon le propose, sans rien lancer d’office.
  const depart = document.body.dataset.depart || "", cree = document.body.dataset.departCree || "";
  const ici = document.body.dataset.ici || "~";
  const sur = /^[\w./-]+$/, surIci = /^[\w./~-]+$/;
  const SITE = "https://jmchantrein.github.io/Cours/";
  const commandeDepart = depart && `cd && curl -fsSLO ${SITE}${depart} && bash ${depart.split("/").pop()}`;

  function el(balise, attributs = {}, ...enfants) {
    const e = document.createElement(balise);
    for (const [k, v] of Object.entries(attributs)) if (v !== false && v != null) e.setAttribute(k, v === true ? "" : v);
    e.append(...enfants);
    return e;
  }
  const code = texte => el("code", {}, texte);
  const mo = octets => (octets / 1e6).toLocaleString("fr-FR", { maximumFractionDigits: octets < 1e7 ? 1 : 0 }) + " Mo";

  // ---------- Volet ----------
  const lanceur = el("button", { type: "button", class: "terminal-lanceur", "aria-expanded": "false",
    "aria-controls": "terminal-volet", title: "Ouvrir le terminal, où s’exécutent les commandes de la page" }, "Terminal");
  bandeau.insertBefore(lanceur, bandeau.querySelector(".variante"));
  const etat = el("span", { class: "terminal-etat", "aria-live": "polite" });
  const actions = el("span", { class: "terminal-actions" });
  const reduire = el("button", { type: "button", title: "Réduire le volet ; la session continue" }, "Réduire");
  const choixModes = modes.map(m => el("button", { type: "button", "aria-pressed": "false" }, NOMS[m]));
  const corps = el("div", { class: "terminal-corps" });
  const volet = el("section", { id: "terminal-volet", class: "terminal-volet", "aria-label": "Terminal", hidden: true },
    el("div", { class: "terminal-entete" }, el("strong", {}, "Terminal"),
      modes.length > 1 ? el("span", { class: "terminal-modes", role: "group", "aria-label": "Mode du terminal" }, ...choixModes)
        : el("span", {}, NOMS[modes[0]]),
      etat, actions, reduire),
    corps);
  const cote = document.querySelector(".page-cours .cote");
  (cote || document.body).append(volet);
  const signaler = (nom, detail) => document.dispatchEvent(new CustomEvent(nom, { detail }));

  const ouvrir = () => {
    volet.hidden = false; document.body.classList.add("terminal-ouvert");
    lanceur.setAttribute("aria-expanded", "true"); actif().preparer?.();
  };
  const fermer = () => {
    volet.hidden = true; document.body.classList.remove("terminal-ouvert"); lanceur.setAttribute("aria-expanded", "false");
  };
  lanceur.addEventListener("click", () => (volet.hidden ? ouvrir() : fermer()));
  reduire.addEventListener("click", fermer);

  // ---------- Bibliothèques, chargées à la demande ----------
  const charges = new Map();
  const script = src => charges.get(src) || charges.set(src, new Promise((ok, ko) => {
    const s = el("script", { src }); s.onload = ok; s.onerror = () => ko(new Error("chargement impossible : " + src));
    document.head.append(s);
  })).get(src);
  async function chargerXterm() {
    if (!document.querySelector("link[data-xterm]")) document.head.append(el("link", { rel: "stylesheet", href: vendor + "xterm.css", "data-xterm": true }));
    await script(vendor + "xterm.js");
    await script(vendor + "addon-fit.js");
    await document.fonts.load('14px "IBM Plex Mono"').catch(() => {});
  }
  // Les couleurs du terminal viennent de la charte, et suivent la variante choisie.
  const theme = () => {
    const s = getComputedStyle(document.documentElement), v = n => s.getPropertyValue(n).trim();
    return { background: v("--c-nuit"), foreground: v("--c-texte-term"), cursor: v("--c-prompt"), cursorAccent: v("--c-nuit"),
      selectionBackground: v("--c-encart") };
  };
  const espacement = () => (document.documentElement.dataset.variante === "dyslexie" ? 1 : 0);
  const terminaux = new Set();
  new MutationObserver(() => terminaux.forEach(t => { t.options.theme = theme(); t.options.letterSpacing = espacement(); }))
    .observe(document.documentElement, { attributes: true, attributeFilter: ["data-variante"] });
  // Crée un xterm dans `ecran` ; `saisie` reçoit la frappe, `taille` chaque nouvelle taille.
  function creerXterm(ecran, saisie, taille = () => {}) {
    const t = new window.Terminal({ fontFamily: '"IBM Plex Mono", ui-monospace, monospace', fontSize: 14, cursorBlink: true,
      scrollback: 5000, theme: theme(), letterSpacing: espacement() });
    const fit = new window.FitAddon.FitAddon();
    t.loadAddon(fit); t.open(ecran); fit.fit();
    t.onData(saisie);
    // La VM décrit, avant chaque invite, le répertoire courant et ce qui l’entoure (vm/contexte.bash) : la séquence
    // n’affiche rien ; son contenu part au repère de contexte de la page.
    t.parser.registerOscHandler(6973, texte => { signaler("terminal-contexte", { texte }); return true; });
    const suivre = new ResizeObserver(() => { if (!ecran.hidden && ecran.clientWidth) { fit.fit(); taille(t.cols, t.rows); } });
    suivre.observe(ecran);
    terminaux.add(t);
    t.fermer = () => { suivre.disconnect(); terminaux.delete(t); t.dispose(); };
    return t;
  }

  // ---------- Mode VM : v86 dans l’onglet, sur le port série ----------
  function modeVM() {
    const m = { id: "vm", session: false };
    const demarrer = el("button", { type: "button", class: "principal" }, "Démarrer la VM");
    const poids = el("span");
    m.accueil = el("div", { class: "terminal-accueil" },
      el("p", {}, "Une VM Linux démarre dans votre navigateur : rien n’est installé sur votre machine, et tout s’efface quand vous fermez la page. Elle n’a pas de réseau."),
      el("p", {}, demarrer, " ", poids),
      el("p", {}, "Votre navigateur garde l’image en cache : les visites suivantes ne la téléchargent plus. Le démarrage prend ensuite une vingtaine de secondes ; une commande cliquée pendant ce temps attend l’invite."));
    m.ecran = el("div", { class: "terminal-ecran", hidden: true });
    // Remettre à l’état de départ : la VM redémarre ; son système, en mémoire, repart de l’image, et le script de
    // départ de la page s’y relance.
    const remettre = el("button", { type: "button", title: "Redémarrer la VM : tout ce que vous avez fait s’efface, l’état de départ de la page est réinstallé" }, "Remettre à l’état de départ");
    m.actions = [remettre];
    let manifeste = null, vm = null, xterm = null, phase = "arret", recents = "", fichiers = null;
    const attente = [];
    const cacheDe = man => PREFIXE_CACHE + man.version;

    // Le manifeste (construit par preparer.sh) donne les fichiers, leur taille et la version de l’image.
    m.preparer = async () => {
      if (manifeste || phase !== "arret") return;
      try {
        const r = await fetch(vendor + "vm/manifeste.json", { cache: "no-cache" });
        if (!r.ok) throw new Error("HTTP " + r.status);
        manifeste = await r.json();
      } catch {
        demarrer.disabled = true;
        poids.textContent = "La VM n’est pas disponible sur ce site : son image n’a pas été construite (commun/terminal/preparer.sh --vm).";
        return;
      }
      const total = Object.values(manifeste.fichiers).reduce((a, b) => a + b, 0);
      const enCache = await caches.has(cacheDe(manifeste)).catch(() => false);
      poids.textContent = enCache ? "Image déjà dans le cache du navigateur : rien à télécharger."
        : `Premier démarrage : ${mo(total)} à télécharger.`;
    };

    // Chaque fichier vient du cache s’il y est, sinon du site, avec la progression ; il est rangé ensuite.
    async function telecharger(man) {
      let cache = null;
      try {
        cache = await caches.open(cacheDe(man));
        for (const nom of await caches.keys()) if (nom.startsWith(PREFIXE_CACHE) && nom !== cacheDe(man)) await caches.delete(nom);
      } catch { cache = null; }
      const total = Object.values(man.fichiers).reduce((a, b) => a + b, 0);
      const barre = el("progress", { max: total, value: 0 }), texte = el("span");
      etat.replaceChildren(barre, texte);
      let recus = 0, telecharges = 0;
      const avancer = n => { recus += n; barre.value = recus; texte.textContent = `Image de la VM : ${mo(recus)} sur ${mo(total)}`; };
      const lire = async chemin => {
        const url = new URL(vendor + chemin, location.href).href;
        const enCache = cache && await cache.match(url);
        let octets;
        if (enCache) {
          octets = await enCache.arrayBuffer(); avancer(octets.byteLength);
        } else {
          const r = await fetch(url);
          if (!r.ok || !r.body) throw new Error(`${chemin} : HTTP ${r.status}`);
          const morceaux = [], lecteur = r.body.getReader();
          for (;;) {
            const { done, value } = await lecteur.read();
            if (done) break;
            morceaux.push(value); avancer(value.length); telecharges += value.length;
          }
          octets = await new Blob(morceaux).arrayBuffer();
        }
        if (octets.byteLength !== man.fichiers[chemin]) {
          if (cache) await cache.delete(url);
          throw new Error(`${chemin} inattendu (site en cours de mise à jour ?) : rechargez la page`);
        }
        if (!enCache && cache) await cache.put(url, new Response(octets)).catch(() => {});
        return [chemin, octets];
      };
      const fichiers = Object.fromEntries(await Promise.all(Object.keys(man.fichiers).map(lire)));
      return { fichiers, telecharges };
    }

    // Le texte part en UTF-8, octet par octet, sur le port série de l’invité.
    const envoyer = texte => {
      let octets = "";
      for (const o of new TextEncoder().encode(texte)) octets += String.fromCharCode(o);
      vm.serial0_send(octets);
    };
    // L’invité prévient par un titre de fenêtre (séquence OSC, invisible) avant de lancer bash ; les commandes
    // en attente partent à la première invite, quand bash lit déjà le clavier : elles ne s’affichent qu’une fois.
    function suivre(octet) {
      recents = (recents + String.fromCharCode(octet)).slice(-200);
      if (phase === "demarrage" && recents.includes("\x1b]0;cours-terminal-pret\x07")) phase = "invite";
      else if (phase === "invite" && /[$#] $/.test(recents)) {
        phase = "prete";
        etat.textContent = "VM prête : les commandes cliquées s’exécutent ici.";
        while (attente.length) envoyer(attente.shift());
      }
    }

    async function lancer() {
      demarrer.disabled = true;
      try {
        await m.preparer();
        if (!manifeste) return;
        phase = "telechargement"; m.session = true; majBoutons();
        await chargerXterm();
        m.accueil.hidden = true; m.ecran.hidden = false;
        xterm = creerXterm(m.ecran, d => (phase === "prete" ? envoyer(d) : undefined));
        let telecharges;
        ({ fichiers, telecharges } = await telecharger(manifeste));
        etat.textContent = (telecharges ? `${mo(telecharges)} téléchargés et rangés dans le cache. ` : "Image lue dans le cache du navigateur : rien à télécharger. ")
          + "Démarrage de la VM…";
        const libv86 = URL.createObjectURL(new Blob([fichiers["libv86.js"]], { type: "text/javascript" }));
        await script(libv86);
        demarrerV86();
        majActions();
        xterm.focus();
      } catch (erreur) {
        phase = "arret"; m.session = false; majBoutons(); demarrer.disabled = false;
        m.accueil.hidden = false; m.ecran.hidden = true;
        if (xterm) { xterm.fermer(); xterm = null; }
        etat.textContent = "Échec du démarrage de la VM : " + erreur.message;
      }
    }
    // La VM, avec l’état de départ de la page passé au noyau (vm/init le lance avant la première invite).
    function demarrerV86() {
      // Le tampon de sortie est vidé dans xterm par paquets, pas octet par octet.
      let tampon = [], planifie = false;
      const vider = () => { xterm.write(new Uint8Array(tampon)); tampon = []; planifie = false; };
      const etatDepart = (sur.test(depart) ? ` depart=${depart}` : "") + (surIci.test(ici) ? ` ici=${ici}` : "");
      vm = new window.V86({
        wasm_fn: async env => (await WebAssembly.instantiate(fichiers["v86.wasm"], env)).instance.exports,
        bios: { buffer: fichiers["seabios.bin"] }, vga_bios: { buffer: fichiers["vgabios.bin"] },
        bzimage: { buffer: fichiers["vm/bzImage"] }, initrd: { buffer: fichiers["vm/initrd.gz"] },
        cmdline: `console=ttyS0,115200 rdinit=/init quiet terminal=${xterm.cols}x${xterm.rows}${etatDepart}`,
        memory_size: manifeste.memoire_mo * 1024 * 1024, vga_memory_size: 2 * 1024 * 1024,
        autostart: true, disable_keyboard: true, disable_mouse: true, disable_speaker: true,
      });
      phase = "demarrage"; recents = "";
      vm.add_listener("serial0-output-byte", octet => {
        tampon.push(octet); suivre(octet);
        if (!planifie) { planifie = true; setTimeout(vider, 15); }
      });
    }
    remettre.addEventListener("click", () => {
      if (!vm || !confirm("Remettre la VM à l’état de départ de la page ? Tout ce que vous y avez fait s’efface.")) return;
      vm.destroy(); attente.length = 0; xterm.reset();
      etat.textContent = "Redémarrage de la VM : l’état de départ de la page se réinstalle…";
      signaler("terminal-session", { mode: "vm", ouverte: true, reinitialise: true });
      demarrerV86(); xterm.focus();
    });
    demarrer.addEventListener("click", lancer);
    // Rend faux si la commande attend l’invite (VM qui démarre).
    m.executer = commande => {
      const texte = commande.replace(/\n/g, "\r") + "\r";
      if (phase === "prete") { envoyer(texte); return true; }
      attente.push(texte); etat.textContent = "Commande en attente : la VM démarre…";
      return false;
    };
    // Écrire : la commande à l’invite, sans Entrée (attend l’invite si la VM démarre).
    m.ecrire = commande => { if (phase === "prete") envoyer(commande); else attente.push(commande); xterm?.focus(); };
    m.inviter = () => { etat.textContent = "Démarrez d’abord la VM, puis cliquez à nouveau sur « Exécuter »."; demarrer.focus(); };
    m.montrer = () => { if (phase === "prete") etat.textContent = "VM prête : les commandes cliquées s’exécutent ici."; };
    return m;
  }

  // ---------- Mode compagnon : le vrai shell de l’étudiant ----------
  function modeCompagnon() {
    const m = { id: "compagnon", session: false };
    const adresse = el("input", { type: "text", spellcheck: "false", autocomplete: "off", placeholder: "ws://localhost:…/?token=…",
      "aria-label": "Adresse affichée par le compagnon" });
    const connecter = el("button", { type: "submit", class: "principal" }, "Connecter");
    const formulaire = el("form", { class: "terminal-appairage" }, adresse, connecter);
    const lien = el("a", { href: guide }, "Installer le compagnon");
    m.accueil = el("div", { class: "terminal-accueil" },
      el("aside", { class: "note", "data-role": "danger" }, el("span", { class: "role" }, "Danger"),
        "Ce mode relie la page à votre vrai shell : un clic sur « Exécuter » lance la commande sur votre machine, avec vos droits. Lisez chaque commande avant de cliquer."),
      el("p", {}, "1. ", lien, " (une fois). 2. Dans un terminal, lancez ", code("./iadmin-terminal local"), ". 3. Collez ici l’adresse qu’il affiche :"),
      formulaire,
      el("p", {}, "Si le navigateur demande l’autorisation d’accéder au réseau local, acceptez : c’est ainsi que la page joint le compagnon, sur votre machine (127.0.0.1)."),
      commandeDepart ? el("p", {}, "État de départ : rien n’est installé d’office sur votre machine. Une fois connecté, le bouton « Installer l’état de départ » lance ",
        code(commandeDepart), ...(cree ? [" ; le script crée ", code(cree), ", un dossier à part, et refuse d’écraser un dossier qui existe déjà."] : [])) : "");
    m.ecran = el("div", { class: "terminal-ecran", hidden: true });
    const deconnecter = el("button", { type: "button" }, "Déconnecter");
    const installer = el("button", { type: "button", title: commandeDepart || "" }, "Installer l’état de départ");
    installer.addEventListener("click", () => {
      if (confirm(`Lancer dans votre shell :\n${commandeDepart}\n${cree ? `Le script crée ${cree} (il refuse d’écraser un dossier existant).` : ""}`)) m.executer(commandeDepart);
    });
    m.actions = commandeDepart ? [installer, deconnecter] : [deconnecter];
    let socket = null, xterm = null;
    const envoyer = message => socket?.readyState === WebSocket.OPEN && (socket.send(JSON.stringify(message)), true);

    formulaire.addEventListener("submit", async evenement => {
      evenement.preventDefault();
      const cible = adresse.value.trim();
      // Le compagnon écoute sur cette machine seulement : toute autre adresse est refusée ici.
      if (!/^wss?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?\/\?token=[\w-]+$/.test(cible)) {
        etat.textContent = "Adresse refusée : collez la ligne ws://localhost:…/?token=… affichée par le compagnon.";
        return;
      }
      connecter.disabled = true; etat.textContent = "Connexion au compagnon…";
      try { await chargerXterm(); } catch (erreur) { etat.textContent = erreur.message; connecter.disabled = false; return; }
      let ouverte = false;
      socket = new WebSocket(cible);
      socket.addEventListener("open", () => {
        ouverte = true; adresse.value = "";
        m.accueil.hidden = true; m.ecran.hidden = false;
        xterm = creerXterm(m.ecran, data => envoyer({ type: "input", data }), (cols, rows) => envoyer({ type: "resize", cols, rows }));
        envoyer({ type: "resize", cols: xterm.cols, rows: xterm.rows });
        m.session = true; majBoutons(); majActions(); xterm.focus();
        etat.textContent = "Connecté à votre shell : les commandes cliquées s’exécutent sur votre machine.";
      });
      socket.addEventListener("message", evenement => {
        let message;
        try { message = JSON.parse(evenement.data); } catch { return; }
        if (message.type === "output" && typeof message.data === "string") xterm?.write(message.data);
      });
      socket.addEventListener("close", () => {
        socket = null; m.session = false; connecter.disabled = false;
        m.accueil.hidden = false; m.ecran.hidden = true;
        if (xterm) { xterm.fermer(); xterm = null; }
        majBoutons(); majActions();
        etat.textContent = ouverte
          ? "Compagnon déconnecté. Pour reprendre, relancez ./iadmin-terminal local et collez la nouvelle adresse."
          : "Connexion impossible : le compagnon est-il lancé ? Son adresse ne sert qu’une fois : relancez-le pour en obtenir une nouvelle.";
      });
    });
    deconnecter.addEventListener("click", () => socket?.close());
    m.executer = commande => envoyer({ type: "input", data: commande.replace(/\n/g, "\r") + "\r" });
    m.ecrire = commande => { envoyer({ type: "input", data: commande }); xterm?.focus(); };
    m.inviter = () => { etat.textContent = "Connectez d’abord le compagnon, puis cliquez à nouveau sur « Exécuter »."; adresse.focus(); };
    m.montrer = () => { if (m.session) etat.textContent = "Connecté à votre shell : les commandes cliquées s’exécutent sur votre machine."; };
    return m;
  }

  // ---------- Modes, boutons « Exécuter » ----------
  const tous = modes.map(id => (id === "vm" ? modeVM() : modeCompagnon()));
  for (const m of tous) corps.append(m.accueil, m.ecran);
  let courant = tous[0];
  try { courant = tous.find(m => m.id === localStorage.getItem("terminal-mode")) || courant; } catch { /* stockage indisponible */ }
  const actif = () => courant;
  function majActions() { actions.replaceChildren(...courant.actions.filter(() => courant.session)); }
  function majBoutons() {
    const ouverte = courant.session;
    signaler("terminal-session", { mode: courant.id, ouverte });
    lanceur.dataset.session = ouverte ? "ouverte" : "";
    for (const b of document.querySelectorAll(".terminal :is(.executer, .ecrire)")) {
      b.setAttribute("aria-disabled", String(!ouverte));
      b.title = !ouverte ? "Ouvrez d’abord le terminal (bandeau, en haut)" : b.classList.contains("ecrire")
        ? `Écrire à l’invite, sans valider : relisez, puis Entrée (${NOMS[courant.id]})` : `Exécuter dans le terminal (${NOMS[courant.id]})`;
    }
  }
  function choisir(m) {
    courant = m;
    tous.forEach((autre, i) => {
      choixModes[i].setAttribute("aria-pressed", String(autre === m));
      // L’écran d’un mode reste en place tant que sa session dure (VM en cours de démarrage comprise).
      autre.accueil.hidden = autre !== m || autre.session; autre.ecran.hidden = autre !== m || !autre.session;
    });
    try { localStorage.setItem("terminal-mode", m.id); } catch { /* choix non mémorisé */ }
    etat.textContent = ""; m.montrer();
    majBoutons(); majActions();
    if (!volet.hidden) m.preparer?.();
  }
  choixModes.forEach((b, i) => b.addEventListener("click", () => choisir(tous[i])));
  choisir(courant);
  // Page de cours, écran large : le terminal est en vue dès l’arrivée, à côté du texte (rien ne se télécharge avant
  // « Démarrer la VM »).
  if (cote && matchMedia("(min-width: 64rem)").matches) ouvrir();

  document.addEventListener("click", evenement => {
    const bouton = evenement.target.closest(".terminal :is(.executer, .ecrire)");
    if (!bouton) return;
    const etaitFerme = volet.hidden;
    ouvrir();
    if (!courant.session) { courant.inviter(); return; }
    if (courant.id === "vm" && bouton.closest('[data-mode="compagnon"]')) {
      etat.textContent = "Inutile dans la VM : l’état de départ de la page y est installé à son démarrage.";
      return;
    }
    if (bouton.classList.contains("ecrire")) {
      courant.ecrire(bouton.dataset.commande);
      etat.textContent = "Commande écrite à l’invite : relisez-la, complétez-la au besoin, puis Entrée.";
      bouton.dataset.etat = "envoyee"; setTimeout(() => delete bouton.dataset.etat, 700);
      return;
    }
    const differee = courant.executer(bouton.dataset.commande) === false;
    signaler("terminal-commande", { commande: bouton.dataset.commande, bouton, mode: courant.id, differee });
    bouton.dataset.etat = "envoyee";
    setTimeout(() => delete bouton.dataset.etat, 700);
    // Le volet qui s’ouvre ne doit pas cacher la commande cliquée.
    if (etaitFerme && getComputedStyle(volet).position === "fixed") {
      const bas = bouton.getBoundingClientRect().bottom, limite = volet.getBoundingClientRect().top;
      if (bas > limite) scrollBy({ top: bas - limite + 16 });
    }
  });
})();
