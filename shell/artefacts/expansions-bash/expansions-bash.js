// expansions-bash.js — simulateur de « Avant d’exécuter, Bash réécrit la ligne », selon le modèle du cours
// (diapos <ordre-expansions>, <guillemets>, <accolades>, <memo-guillemets> et l’exercice <exercice-expansions>) :
// Bash coupe la ligne en mots, puis, mot par mot et dans cet ordre, il développe
//   2. les accolades  {a,b}  {1..3}
//   3. le tilde ~, les variables $nom ${nom} et les substitutions $( ) (de gauche à droite)
//   4. découpe en mots les résultats de l’étape 3 qui ne sont pas entre guillemets (IFS par défaut : espace, tabulation, saut de ligne)
//   5. remplace les motifs * et ? (hors guillemets) par les noms de fichiers qui correspondent
//   6. retire les guillemets : la commande reçoit ses arguments (argv).
// Les guillemets doubles empêchent les étapes 2, 4 et 5 (et laissent agir 3) ; les simples, toutes ; l’antislash protège un caractère.
//
// Le simulateur (partie pure, sans DOM) suit Bash 5.2 exécutant un script (`bash -c`, pas un shell interactif), dans un
// SOUS-ENSEMBLE DÉFINI de sa syntaxe : mots, guillemets simples, doubles et $'…' (\n \t \\ \' \"), antislash, $nom et
// ${nom}, $(echo …), accolades {a,b} et {n..m}, tilde seul, * et ? sur la liste de fichiers (dossiers compris), IFS par défaut.
// Tout le reste est DÉTECTÉ et déclaré (« Limitation du simulateur : … »), jamais simulé à peu près : l’analyseur refuse ce
// qu’il ne reconnaît pas. Il est confronté au vrai Bash par verifier-bash.js ; Bash fait foi.
// Les explications sont calculées à partir du résultat de la simulation, jamais écrites d’avance.
(() => {
  const HOME = "/home/ada", PWD = "/home/ada/labo";
  const MAX_MOTS = 200;
  const limite = texte => { throw { limite: texte }; };
  const refus = texte => { throw { erreur: texte }; };

  // ---------- Variables : ce que le simulateur connaît ----------
  const NOM_VALIDE = /^[A-Za-z_][A-Za-z0-9_]*$/;
  // Variables du shell ou de l'environnement : leur valeur dépend de la machine, le simulateur ne les prétend pas connues.
  const SPECIALES = new Set(("PATH USER LOGNAME SHELL OLDPWD RANDOM SRANDOM SECONDS LINENO UID EUID PPID GROUPS HOSTNAME HOSTTYPE " +
    "MACHTYPE OSTYPE SHLVL TERM LANG LANGUAGE EDITOR VISUAL PS1 PS2 PS3 PS4 OPTIND OPTARG OPTERR REPLY COLUMNS LINES IFS MAIL " +
    "TMPDIR DISPLAY FUNCNAME PIPESTATUS EPOCHSECONDS EPOCHREALTIME SHELLOPTS TIMEFORMAT CDPATH ENV TZ PROMPT_COMMAND " +
    "COMP_WORDS COMPREPLY DIRSTACK MAPFILE READLINE_LINE TMOUT FCEDIT PAGER MANPATH").split(" "));
  const specialeNom = nom => SPECIALES.has(nom) || /^(BASH|LC_|HIST|XDG_|READLINE_)/.test(nom);
  const RESERVES = new Set(["HOME", "PWD"]);   // définies par le simulateur : HOME = /home/ada, PWD = /home/ada/labo
  const MOTS_RESERVES = new Set("if then else elif fi for while until do done case esac in function select time coproc".split(" "));
  const DECLARATIONS = new Set("export declare typeset local readonly".split(" "));

  // ---------- Lecture d'une unité de syntaxe ----------
  // Une « unité » est ce qui se lit d'un bloc dans un mot : un caractère, '…', "…", $'…', \c, ${nom}, $nom, $(…).
  // `brut` : au niveau du mot, $nom n'est pas une unité (les accolades, développées avant les variables, peuvent encore
  // changer le nom : $p{a,b} est $pa et $pb).
  const NOM_DEBUT = /[A-Za-z_]/, NOM_CAR = /[A-Za-z0-9_]/;
  const ANSI = { n: "\n", t: "\t", "\\": "\\", "'": "'", '"': '"' };
  function trouverFinCommande(s, i) {
    let j = i + 2;
    while (j < s.length) {
      const c = s[j];
      if (c === "'") { const k = s.indexOf("'", j + 1); if (k < 0) refus("guillemet simple non fermé"); j = k + 1; continue; }
      if (c === '"') {
        j++;
        while (j < s.length && s[j] !== '"') {
          if (s[j] === "\\") j++;
          else if (s[j] === "$" && s[j + 1] === "(") limite("substitution de commande imbriquée");
          else if (s[j] === "`") limite("apostrophe inversée (ancienne substitution de commande)");
          j++;
        }
        if (j >= s.length) refus("guillemet double non fermé");
        j++; continue;
      }
      if (c === "\\") { j += 2; continue; }
      if (c === "(") limite("parenthèse ou sous-shell dans $( … ) : seule `$(echo …)` simple est simulée");
      if (c === "`") limite("apostrophe inversée (ancienne substitution de commande)");
      if (c === ")") return j;
      j++;
    }
    refus("parenthèse « ) » manquante après $(");
  }
  function dollar(s, i, ctx, brut) {
    const n = s[i + 1], litteral = { t: "c", raw: "$", txt: "$", fin: i + 1 };
    if (n === "'") {
      if (ctx === "dq") return litteral;
      const parts = [];
      let j = i + 2;
      for (; j < s.length && s[j] !== "'"; j++) {
        if (s[j] === "\\") {
          const e = s[j + 1];
          if (e === undefined || !(e in ANSI)) limite("$'…' avec une séquence d’échappement autre que \\n, \\t, \\\\, \\' et \\\"");
          parts.push({ c: "\\" + e, v: ANSI[e] }); j++;
        } else parts.push({ c: s[j], v: s[j] });
      }
      if (j >= s.length) refus("guillemet simple non fermé");
      return { t: "ansi", raw: s.slice(i, j + 1), parts, fin: j + 1 };
    }
    if (n === '"') { if (ctx === "dq") return litteral; limite("$\"…\" (traduction de messages)"); }
    if (n === "{") {
      const j = s.indexOf("}", i + 2);
      if (j < 0) refus("${ sans accolade fermante");
      const nom = s.slice(i + 2, j);
      if (!NOM_VALIDE.test(nom)) limite("expansion de paramètre autre que ${nom} (valeur par défaut, longueur, découpe, indice…)");
      if (nom === "_") limite("la variable spéciale $_");
      return { t: "var", nom, raw: s.slice(i, j + 1), fin: j + 1 };
    }
    if (n === "(") {
      if (s[i + 2] === "(") limite("arithmétique $(( … ))");
      const j = trouverFinCommande(s, i);
      return { t: "cmd", inner: s.slice(i + 2, j), raw: s.slice(i, j + 1), fin: j + 1 };
    }
    if (n === "[") limite("arithmétique $[ … ]");
    if (n !== undefined && NOM_DEBUT.test(n)) {
      if (brut) return litteral;
      let j = i + 1;
      while (j < s.length && NOM_CAR.test(s[j])) j++;
      const nom = s.slice(i + 1, j);
      if (nom === "_") limite("la variable spéciale $_");
      return { t: "var", nom, raw: s.slice(i, j), fin: j };
    }
    if (n !== undefined && /[0-9@*#?$!-]/.test(n)) limite(`paramètre positionnel ou spécial $${n} (arguments du script, code de retour, $@…)`);
    return litteral;
  }
  function guillemetsDoubles(s, i) {
    const parts = [];
    let j = i + 1;
    while (j < s.length && s[j] !== '"') {
      const c = s[j];
      if (c === "\\") {
        const n = s[j + 1];
        if (n === undefined) refus("guillemet double non fermé");
        if ("$`\"\\".includes(n)) { parts.push({ t: "esc", raw: "\\" + n, txt: n }); j += 2; }
        else { parts.push({ t: "c", raw: "\\", txt: "\\" }); j++; }
      } else if (c === "$") { const u = dollar(s, j, "dq", false); parts.push(u); j = u.fin; }
      else if (c === "`") limite("apostrophe inversée (ancienne substitution de commande)");
      else { parts.push({ t: "c", raw: c, txt: c }); j++; }
    }
    if (j >= s.length) refus("guillemet double non fermé");
    return { t: "dq", raw: s.slice(i, j + 1), parts, fin: j + 1 };
  }
  function unite(s, i, brut = false) {
    const c = s[i];
    if (c === "'") {
      const j = s.indexOf("'", i + 1);
      if (j < 0) refus("guillemet simple non fermé");
      return { t: "sq", raw: s.slice(i, j + 1), txt: s.slice(i + 1, j), fin: j + 1 };
    }
    if (c === '"') return guillemetsDoubles(s, i);
    if (c === "\\") {
      if (i + 1 >= s.length) limite("barre oblique inverse en fin de ligne (continuation de ligne)");
      return { t: "esc", raw: s.slice(i, i + 2), txt: s[i + 1], fin: i + 2 };
    }
    if (c === "`") limite("apostrophe inversée (ancienne substitution de commande)");
    if (c === "$") return dollar(s, i, "nu", brut);
    return { t: "c", raw: c, txt: c, fin: i + 1 };
  }
  const OPERATEURS = { "|": "un tube ou « || »", "&": "« & » ou « && »", ";": "un « ; »", "<": "une redirection « < »", ">": "une redirection « > »", "(": "une parenthèse (sous-shell, fonction, extglob…)", ")": "une parenthèse" };

  // ---------- Étape 1 : la ligne est coupée en mots ----------
  function decouperMots(ligne) {
    if (/[\n\r]/.test(ligne)) limite("plusieurs lignes : le simulateur lit une seule ligne de commande");
    const mots = [];
    let i = 0, debut = -1;
    const fermer = fin => { if (debut >= 0) { mots.push(ligne.slice(debut, fin)); debut = -1; } };
    while (i < ligne.length) {
      const c = ligne[i];
      if (c === " " || c === "\t") { fermer(i); i++; continue; }
      if (c in OPERATEURS) limite(`${OPERATEURS[c]} : le simulateur ne lit que des mots, pas les opérateurs du shell`);
      if (c === "#" && debut < 0) limite("commentaire (« # » en début de mot : Bash ignore la suite de la ligne)");
      if (debut < 0) debut = i;
      const u = unite(ligne, i, true);
      if (u.t === "c" && c === "[" && mots.length > 0) limite("motif entre crochets […] : classe de caractères non simulée");
      i = u.fin;
    }
    fermer(ligne.length);
    return mots;
  }
  function verifierCommande(mot) {
    if (/^[A-Za-z_][A-Za-z0-9_]*\+?=/.test(mot)) limite("affectation de variable (nom=valeur) : le simulateur ne lit que des commandes");
    if (!/^(\[|[A-Za-z][A-Za-z0-9_.+:@%,-]*|\.{1,2}\/[A-Za-z0-9_.\/-]+)$/.test(mot))
      limite("nom de commande avec des guillemets ou des expansions : le simulateur développe les arguments, pas le nom de la commande");
    if (MOTS_RESERVES.has(mot) || mot === "[[") limite(`mot réservé « ${mot} » (structure de contrôle)`);
    if (DECLARATIONS.has(mot)) limite(`« ${mot} » : ses arguments de la forme nom=valeur sont développés autrement (sans découpage)`);
  }

  // ---------- Étape 2 : accolades ----------
  const jetons = raw => { const r = []; for (let i = 0; i < raw.length;) { const u = unite(raw, i, true); r.push(u); i = u.fin; } return r; };
  const lit = (j, c) => j.t === "c" && j.raw === c;
  function apparier(tok, i) {
    let prof = 0;
    for (let k = i; k < tok.length; k++) {
      if (lit(tok[k], "{")) prof++; else if (lit(tok[k], "}")) { prof--; if (prof === 0) return k; }
    }
    return -1;
  }
  const NOMBRE = "(?:0|-?[1-9][0-9]*)";
  const SEQUENCE = new RegExp(`^(${NOMBRE})\\.\\.(${NOMBRE})$`);
  const jetonsDe = texte => [...texte].map(c => ({ t: "c", raw: c, txt: c }));
  // Alternatives (tableaux de jetons) du premier groupe valable ; Bash : le plus à gauche, le texte avant reste tel quel.
  function accolades(tok, budget) {
    for (let i = 0; i < tok.length; i++) {
      if (!lit(tok[i], "{")) continue;
      const j = apparier(tok, i);
      if (j < 0) continue;
      const contenu = tok.slice(i + 1, j);
      const parts = [];
      let prof = 0, debut = 0;
      contenu.forEach((t, k) => {
        if (lit(t, "{")) prof++; else if (lit(t, "}")) prof--;
        else if (lit(t, ",") && prof === 0) { parts.push(contenu.slice(debut, k)); debut = k + 1; }
      });
      let alternatives;
      if (parts.length) { parts.push(contenu.slice(debut)); alternatives = parts; }
      else {
        const texte = contenu.map(t => t.raw).join("");
        const m = SEQUENCE.exec(texte);
        if (m && contenu.every(t => t.t === "c")) {
          const a = +m[1], b = +m[2], pas = a <= b ? 1 : -1, n = Math.abs(b - a) + 1;
          if (n > MAX_MOTS) limite(`séquence de plus de ${MAX_MOTS} éléments`);
          alternatives = Array.from({ length: n }, (_, k) => jetonsDe(String(a + k * pas)));
        } else if (texte.includes("..")) limite("séquence {…..…} autre que deux entiers sans zéro initial ni pas ({a..e}, {01..10}, {1..10..2}…)");
        else continue;   // {a} ou {} : aucun effet, le texte reste tel quel
      }
      const avant = tok.slice(0, i), apres = accolades(tok.slice(j + 1), budget);
      const sortie = [];
      for (const alt of alternatives) for (const e of accolades(alt, budget)) for (const p of apres) {
        sortie.push([...avant, ...e, ...p]);
        if (sortie.length > MAX_MOTS || (budget.n += 1) > 4 * MAX_MOTS) limite(`expansion de plus de ${MAX_MOTS} mots`);
      }
      return sortie;
    }
    return [tok];
  }
  // Les mêmes jetons, comme si les guillemets et l'antislash n'existaient pas : ce que les accolades auraient fait sans eux.
  const aplatir = tok => tok.flatMap(t => t.t === "sq" ? jetonsDe(t.txt) : t.t === "dq" ? jetonsDe(t.raw.slice(1, -1)) : t.t === "esc" ? jetonsDe(t.txt) : [t]);
  const GENRE_GUILLEMET = { sq: "guillemets simples", dq: "guillemets doubles", esc: "antislash", ansi: "$'…'" };
  const genreDe = u => GENRE_GUILLEMET[u.t];

  // ---------- Cellules : la représentation d'un mot, caractère par caractère ----------
  // Une cellule : { c: texte affiché, v?: valeur si elle diffère ($'\t'), m: marque (guillemet, antislash : retirée à l'étape 6),
  //   q: protection (null : aucune ; 'd' doubles, 's' simples, 'e' antislash, 'a' $'…', 't' tilde, 'g' nom de fichier),
  //   x: numéro de l'expansion qui a produit la cellule, src: son écriture }.
  const cell = (c, q, extra) => ({ c, q, ...extra });
  const marque = (c, q) => ({ c, q, m: true });
  function valeurVariable(nom, K) {
    if (nom === "HOME") return HOME;
    if (nom === "PWD") return PWD;
    if (specialeNom(nom)) limite(`la variable $${nom}, propre au shell ou à l’environnement : sa valeur dépend de la machine`);
    return K.variables.get(nom) ?? "";
  }
  function evaluerCommande(inner, K) {
    const mots = decouperMots(inner.trim());
    if (mots.length === 0) return "";
    if (mots[0] !== "echo") limite(`$(${inner.trim()}) : seule la commande echo est simulée dans $( … ), faute de pouvoir exécuter les autres`);
    const r = chaine(mots.slice(1), K);
    if (/^-[neE]+$/.test(r.argv[0] ?? "")) limite("echo avec une option (-n, -e, -E)");
    return r.argv.join(" ").replace(/\n+$/, "");
  }
  // Étape 3 sur un mot : tilde, variables, substitutions, de gauche à droite. K === null : on lit seulement les guillemets
  // (étapes 1 et 2 : la ligne telle qu'écrite).
  function cellules(raw, K, motIndex) {
    const cells = [], notes = [];
    let i = 0;
    const evenement = (src, valeur, q) => {
      const id = K ? K.compteur.n++ : 0;
      if (K) K.evenements.push({ id, src, valeur, q, origine: motIndex });
      return { id, src };
    };
    const valeurs = (src, valeur, q) => {
      const { id } = evenement(src, valeur, q);
      for (const c of valeur) cells.push(cell(c, q, { x: id, src }));
    };
    if (K && raw[0] === "~") {
      const n = raw[1];
      if (n === undefined || n === "/" || n === ":") { valeurs("~", HOME, "t"); i = 1; notes.push({ genre: "tilde", valeur: HOME }); }
      else if (/[A-Za-z0-9_.+-]/.test(n)) limite("~nom, ~+ ou ~- (le répertoire d’un autre utilisateur ou le dossier courant)");
    }
    if (K && /^[A-Za-z_][A-Za-z0-9_]*\+?=/.test(raw) && /(=|:)~/.test(raw.slice(raw.indexOf("=")))) limite("tilde dans un mot de la forme nom=valeur (Bash le développe aussi après = et :)");
    const dev = (u, q) => {
      if (u.t === "var") {
        const valeur = valeurVariable(u.nom, K);
        valeurs(u.raw, valeur, q);
      } else {
        const valeur = evaluerCommande(u.inner, K);
        valeurs(u.raw, valeur, q);
      }
    };
    const brutes = (u, q) => { for (const c of u.raw) cells.push(cell(c, q)); };
    while (i < raw.length) {
      const u = unite(raw, i, !K);
      i = u.fin;
      if (u.t === "c") cells.push(cell(u.txt, null));
      else if (u.t === "esc") {
        cells.push(marque("\\", "e"), cell(u.txt, "e"));
        if (K && u.txt === "$" && /^[A-Za-z_{(]/.test(raw[i] ?? "")) notes.push({ genre: "expansion-gardee", par: "antislash", ce: u.raw + raw[i] });
      } else if (u.t === "sq") {
        cells.push(marque("'", "s"));
        for (const c of u.txt) cells.push(cell(c, "s"));
        cells.push(marque("'", "s"));
        for (const m of u.txt.matchAll(/\$([A-Za-z_{(])/g)) { notes.push({ genre: "expansion-gardee", par: "guillemets simples", ce: "$" + m[1] }); break; }
      } else if (u.t === "dq") {
        cells.push(marque('"', "d"));
        for (const p of u.parts) {
          if (p.t === "c") cells.push(cell(p.txt, "d"));
          else if (p.t === "esc") {
            cells.push(marque("\\", "d"), cell(p.txt, "d"));
            if (p.txt === "$") notes.push({ genre: "expansion-gardee", par: "antislash", ce: "\\$" });
          } else if (K) dev(p, "d"); else brutes(p, "d");
        }
        cells.push(marque('"', "d"));
      } else if (u.t === "ansi") {
        cells.push(marque("$'", "a"));
        for (const p of u.parts) cells.push(cell(p.c, "a", p.c === p.v ? {} : { v: p.v }));
        cells.push(marque("'", "a"));
      } else if (K) dev(u, null); else brutes(u, null);
    }
    return { cells, notes };
  }
  // Un mot qui commence par ~ entre guillemets : le tilde est gardé.
  function noteTildeGarde(raw) {
    const m = /^(["'])~|^\\~/.exec(raw);
    return m ? { genre: "tilde-garde", par: raw[0] === '"' ? "guillemets doubles" : raw[0] === "'" ? "guillemets simples" : "antislash", ce: raw[0] === "\\" ? "\\~" : raw[0] + "~" + raw[0] } : null;
  }
  const texte = cells => cells.map(c => c.c).join("");

  // ---------- Étape 4 : découpage en mots ----------
  const SEPARATEUR_IFS = /[ \t\n]/;
  function decouper(cells) {
    const champs = [];
    let cur = [];
    for (const c of cells) {
      if (!c.m && c.x !== undefined && c.q === null && SEPARATEUR_IFS.test(c.c)) { if (cur.length) champs.push(cur); cur = []; continue; }
      cur.push(c);
    }
    if (cur.length) champs.push(cur);
    return champs;
  }

  // ---------- Étape 5 : chemins ----------
  // Le répertoire courant : une liste de chemins ; un chemin terminé par « / » est un dossier (éventuellement vide).
  function arbreDe(entrees) {
    const racine = { dossier: true, enfants: new Map() };
    const avertissements = [];
    const vus = [];
    for (const brut of entrees) {
      const dossierSeul = brut.endsWith("/");
      const segments = brut.split("/").filter((s, k, t) => !(dossierSeul && k === t.length - 1 && s === ""));
      if (!segments.length || segments.some(s => s === "" || s === "." || s === ".." || /[\x00-\x1f\x7f]/.test(s))) { avertissements.push(`« ${brut} » n’est pas un nom de fichier valable : ignoré`); continue; }
      let n = racine, ok = true;
      segments.forEach((s, k) => {
        if (!ok) return;
        let e = n.enfants.get(s);
        const dernier = k === segments.length - 1;
        if (!e) { e = { dossier: !dernier || dossierSeul, enfants: new Map() }; n.enfants.set(s, e); }
        else if (!e.dossier && !dernier) { e.dossier = true; avertissements.push(`« ${segments.slice(0, k + 1).join("/")} » est à la fois un fichier et un dossier : dossier retenu`); }
        else if (dernier && !dossierSeul && e.dossier && e.enfants.size) { avertissements.push(`« ${brut} » est déjà un dossier : ignoré`); ok = false; }
        n = e;
      });
      if (ok) vus.push(brut);
    }
    const liste = [];
    const parcourir = (n, prefixe) => { for (const [nom, e] of [...n.enfants].sort((a, b) => (a[0] < b[0] ? -1 : 1))) { if (e.dossier && !e.enfants.size) liste.push(prefixe + nom + "/"); else if (e.dossier) parcourir(e, prefixe + nom + "/"); else liste.push(prefixe + nom); } };
    parcourir(racine, "");
    return { racine, liste, avertissements };
  }
  const echapper = c => c.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
  // Un segment de motif (cellules) : un nom, ou un motif avec * et ?.
  function segmentVersRegex(seg) {
    return new RegExp("^" + seg.map(c => c.q === null && c.c === "*" ? "[^]*" : c.q === null && c.c === "?" ? "[^]" : echapper(c.c)).join("") + "$");
  }
  const segmentActif = seg => seg.some(c => c.q === null && (c.c === "*" || c.c === "?"));
  // Les chemins qui correspondent au motif (liste vide : aucun).
  function chemins(champ, K) {
    const contenu = champ.filter(c => !c.m);
    const actif = contenu.some(c => c.q === null && (c.c === "*" || c.c === "?"));
    if (contenu.some(c => c.q === null && c.c === "[")) limite("motif entre crochets […] : classe de caractères non simulée");
    if (!actif) return null;
    if (contenu.some(c => c.x !== undefined && c.q === null && c.c === "\\")) limite("une barre oblique inverse hors guillemets dans une valeur développée, avec un motif * ou ?");
    const segments = [[]];
    for (const c of contenu) { if (c.c === "/") segments.push([]); else segments.at(-1).push(c); }
    if (segments[0].length === 0 && segments.length > 1) limite("motif sur un chemin absolu (le simulateur ne connaît que le dossier courant)");
    const dossierSeul = segments.length > 1 && segments.at(-1).length === 0;
    if (dossierSeul) segments.pop();
    if (segments.some(s => s.length === 0)) limite("motif avec « // » (barres obliques doublées)");
    if (segments.some(s => { const t = s.map(c => c.c).join(""); return t === ".." || (!segmentActif(s) && t === "."); })) limite("motif avec « .. » ou « . » comme dossier");
    const resultat = [];
    const descendre = (noeud, k, prefixe) => {
      const seg = segments[k], dernier = k === segments.length - 1;
      let noms;
      if (segmentActif(seg)) {
        const re = segmentVersRegex(seg);
        const pointOk = seg[0].c === ".";
        noms = [...noeud.enfants.keys()].filter(nom => re.test(nom) && (pointOk || nom[0] !== ".")).sort((a, b) => (a < b ? -1 : 1));
      } else {
        const nom = seg.map(c => c.c).join("");
        noms = noeud.enfants.has(nom) ? [nom] : [];
      }
      for (const nom of noms) {
        const e = noeud.enfants.get(nom);
        if (dernier) { if (!dossierSeul || e.dossier) resultat.push(prefixe + nom + (dossierSeul ? "/" : "")); }
        else if (e.dossier) descendre(e, k + 1, prefixe + nom + "/");
      }
    };
    descendre(K.arbre.racine, 0, "");
    return resultat.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));   // Bash trie les chemins entiers (ordre des octets, locale C)
  }

  // ---------- Les étapes 2 à 6 sur une liste de mots (la ligne, ou l'intérieur d'un $(echo …)) ----------
  function chaine(mots, K) {
    const etapes = { accolades: [], developpe: [], decoupe: [], chemins: [], notes: [] };
    mots.forEach((raw, i) => {
      // Étape 2
      const tok = jetons(raw);
      const reels = accolades(tok, { n: 0 });
      const alt = reels.map(t => t.map(j => j.raw).join(""));
      const sans = accolades(aplatir(tok), { n: 0 }).map(t => t.map(j => j.raw).join(""));
      if (alt.length > 1 || alt[0] !== raw) etapes.notes.push({ etape: 2, origine: i, genre: "accolades", source: raw, produit: alt });
      if (JSON.stringify(sans) !== JSON.stringify(alt)) {
        const gardes = tok.filter(t => ["sq", "dq", "esc"].includes(t.t) && /[{},.]/.test(t.raw));
        const par = [...new Set(gardes.map(genreDe))];
        etapes.notes.push({ etape: 2, origine: i, genre: "accolades-gardees", par, ce: gardes.map(g => g.raw).join(" ") });
      }
      alt.forEach(a => etapes.accolades.push({ o: i, raw: a }));
    });
    // Étapes 3 à 5, mot par mot
    for (const { o, raw } of etapes.accolades) {
      const tg = noteTildeGarde(raw);
      if (tg) etapes.notes.push({ etape: 3, origine: o, ...tg });
      const evAvant = K.evenements.length;
      const { cells, notes } = cellules(raw, K, o);
      for (const n of notes) etapes.notes.push({ etape: 3, origine: o, ...n });
      const evs = K.evenements.slice(evAvant);
      for (const e of evs) etapes.notes.push({ etape: 3, origine: o, genre: "expansion", src: e.src, valeur: e.valeur, q: e.q, id: e.id });
      etapes.developpe.push({ o, cells, raw, evs });
    }
    for (const w of etapes.developpe) {
      const champs = decouper(w.cells);
      for (const e of w.evs) {
        if (e.q === "t") continue;
        const contient = /[ \t\n]/.test(e.valeur);
        if (e.q === null) {
          if (e.valeur === "") etapes.notes.push({ etape: 4, origine: w.o, genre: "vide-disparait", src: e.src, id: e.id });
          else if (contient) {
            const morceaux = e.valeur.split(/[ \t\n]+/).filter(Boolean).length;
            etapes.notes.push({ etape: 4, origine: w.o, genre: "decoupe", src: e.src, valeur: e.valeur, morceaux, id: e.id });
          }
        } else if (e.q === "d") {
          if (e.valeur === "") etapes.notes.push({ etape: 4, origine: w.o, genre: "vide-garde", src: e.src, id: e.id });
          else if (contient) etapes.notes.push({ etape: 4, origine: w.o, genre: "garde-d-un-bloc", src: e.src, valeur: e.valeur, id: e.id });
        }
      }
      for (const champ of champs) etapes.decoupe.push({ o: w.o, cells: champ });
    }
    for (const { o, cells } of etapes.decoupe) {
      const trouves = chemins(cells, K);
      const motif = texte(cells);
      if (trouves === null) {
        const gardes = cells.filter(c => !c.m && c.q !== null && c.q !== "t" && c.q !== "g" && (c.c === "*" || c.c === "?"));
        if (gardes.length) etapes.notes.push({ etape: 5, origine: o, genre: "chemins-gardes", par: [...new Set(gardes.map(c => ({ d: "guillemets doubles", s: "guillemets simples", e: "antislash", a: "$'…'" }[c.q])))], ce: motif });
        etapes.chemins.push({ o, cells, motif: null, trouves: null });
      } else {
        etapes.notes.push({ etape: 5, origine: o, genre: trouves.length ? "chemins" : "aucun", motif, fichiers: trouves });
        etapes.chemins.push({ o, cells, motif, trouves });
      }
    }
    // Étape 6
    const final = [];
    for (const f of etapes.chemins) {
      if (f.trouves && f.trouves.length) for (const t of f.trouves) final.push({ o: f.o, texte: t, retire: [] });
      else final.push({ o: f.o, texte: f.cells.filter(c => !c.m).map(c => c.v ?? c.c).join(""), retire: f.cells.filter(c => c.m || c.v !== undefined) });
    }
    return { etapes, argv: final.map(f => f.texte), final };
  }

  // ---------- Entrées : variables et fichiers ----------
  // Une ligne « nom=valeur » par variable (la valeur peut contenir des espaces, des guillemets, être vide).
  function lireVariables(texteVariables) {
    const liste = [], avertissements = [];
    for (const ligne of texteVariables.split("\n")) {
      if (ligne.trim() === "") continue;
      const k = ligne.indexOf("=");
      const nom = k < 0 ? ligne.trim() : ligne.slice(0, k).trim();
      if (k < 0 || !NOM_VALIDE.test(nom)) { avertissements.push(`« ${ligne} » : une variable s’écrit nom=valeur, avec un nom de lettres, chiffres et _`); continue; }
      if (RESERVES.has(nom) || specialeNom(nom)) { avertissements.push(`« ${nom} » est une variable du shell : elle n’est pas modifiable ici`); continue; }
      liste.push([nom, ligne.slice(k + 1).replace(/\r$/, "")]);
    }
    return { liste, avertissements };
  }
  function lireFichiers(texteFichiers) {
    return texteFichiers.split("\n").map(l => l.replace(/\r$/, "")).filter(l => l !== "");
  }

  // ---------- Le simulateur ----------
  // entree : { ligne, variables: [[nom, valeur], …], fichiers: [chemin, …] }
  function simuler(entree) {
    const arbre = arbreDe(entree.fichiers);
    const K = { variables: new Map(entree.variables), arbre, evenements: [], compteur: { n: 1 } };
    const res = { entree, limites: [], erreur: null, vide: false, commande: null, fichiers: arbre.liste, avertissements: arbre.avertissements };
    try {
      const mots = decouperMots(entree.ligne);
      if (!mots.length) { res.vide = true; return res; }
      verifierCommande(mots[0]);
      res.commande = mots[0];
      res.reste = entree.ligne.slice(entree.ligne.indexOf(mots[0]) + mots[0].length);
      const args = mots.slice(1);
      const r = chaine(args, K);
      const cellulesBrutes = raw => cellules(raw, null, 0).cells;
      const mot = (o, cells) => ({ o, cells });
      res.etapes = [
        { n: 1, id: "mots", nom: "Mots", mots: args.map((raw, i) => mot(i, cellulesBrutes(raw))) },
        { n: 2, id: "accolades", nom: "Accolades", mots: r.etapes.accolades.map(a => mot(a.o, cellulesBrutes(a.raw))) },
        { n: 3, id: "tilde", nom: "Tilde, $, $( )", mots: r.etapes.developpe.map(w => mot(w.o, w.cells)) },
        { n: 4, id: "decoupage", nom: "Découpage", mots: r.etapes.decoupe.map(f => mot(f.o, f.cells)) },
        { n: 5, id: "chemins", nom: "Chemins", mots: r.etapes.chemins.flatMap(f => f.trouves && f.trouves.length ? f.trouves.map(t => mot(f.o, [...t].map(c => cell(c, "g")))) : [mot(f.o, f.cells)]) },
        { n: 6, id: "guillemets", nom: "Guillemets", mots: r.final.map(f => ({ o: f.o, texte: f.texte })) },
      ];
      res.notes = r.etapes.notes;
      res.argv = r.argv;
      res.motsLigne = args;
      res.marquesRetirees = r.final.flatMap(f => f.retire);
    } catch (e) {
      if (e && e.limite) res.limites.push(e.limite);
      else if (e && e.erreur) res.erreur = e.erreur;
      else throw e;
    }
    return res;
  }
  const entreeDe = etat => {
    const v = lireVariables(etat.variables);
    return { ligne: etat.ligne, variables: v.liste, fichiers: lireFichiers(etat.fichiers) };
  };

  const CAS_DES_RECETTES = [];
  Object.assign(typeof module !== "undefined" ? module.exports : (globalThis.ExpansionsBash = {}), { simuler, entreeDe, lireVariables, lireFichiers, arbreDe, decouperMots, texte, HOME, PWD, CAS_DES_RECETTES });
  if (typeof document === "undefined") return;
})();
