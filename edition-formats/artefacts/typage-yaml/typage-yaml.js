// typage-yaml.js — simulateur de « Le typage implicite des scalaires YAML et sa traduction en JSON », selon le modèle
// du cours (diapos <yaml-typage> et <yaml-json-correspondance>) :
// - un scalaire nu prend le type dont il a la forme, d'après les motifs du schéma de la version que suit l'analyseur ;
//   le premier motif qui reconnaît le texte décide ; entre guillemets, ou avec une étiquette (!!str, !!int…), le type est imposé ;
// - YAML 1.1 (PyYAML 6.0.2) et YAML 1.2, schéma de base (ruamel.yaml 0.18.10, YAML(typ="safe", pure=True)), diffèrent
//   par leurs motifs : yes/no/on/off, 0644 et 0o644, 22:22 en base 60, la notation scientifique…
// - convertir en JSON, c'est réécrire l'arbre lu : un type que JSON n'a pas (la date) fait échouer json.dumps ;
//   une clé qui n'est pas une chaîne devient une chaîne.
//
// Les motifs et les constructeurs sont ceux des deux analyseurs réels (resolver.py et constructor.py), recopiés tels quels :
// les analyseurs font foi, pas la lecture qu'on se fait de la spécification. Quand un analyseur s'écarte de sa spécification,
// le simulateur suit l'analyseur et l'explication le dit.
// Le simulateur (la partie pure, sans DOM) est confronté aux deux analyseurs réels par verifier-analyseurs.js.
// Ce qu'il ne sait pas lire (ancres, blocs multilignes, flux imbriqués, mappings imbriqués…), il le dit : « Limitation
// du simulateur : … ». Les explications sont calculées à partir du résultat de la simulation, jamais écrites d'avance.
(() => {
  // ---------- Outils : ce que fait Python ----------
  const PRINTABLE_NON = /[^\x09\x0A\x0D\x20-\x7E\x85\xA0-\uD7FF\uE000-\uFFFD]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
  const pyStr = s => {
    const q = s.includes("'") && !s.includes('"') ? '"' : "'";
    let r = q;
    for (const c of s) {
      const n = c.codePointAt(0);
      if (c === q || c === "\\") r += "\\" + c;
      else if (c === "\n") r += "\\n"; else if (c === "\r") r += "\\r"; else if (c === "\t") r += "\\t";
      else if (/[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}\p{Zl}\p{Zp}\p{Zs}]/u.test(c) && c !== " ")
        r += n < 0x100 ? "\\x" + n.toString(16).padStart(2, "0") : n < 0x10000 ? "\\u" + n.toString(16).padStart(4, "0") : "\\U" + n.toString(16).padStart(8, "0");
      else r += c;
    }
    return r + q;
  };
  const pyFloat = x => {
    if (x !== x) return "nan";
    if (x === Infinity) return "inf";
    if (x === -Infinity) return "-inf";
    if (x === 0) return Object.is(x, -0) ? "-0.0" : "0.0";
    const signe = x < 0 ? "-" : "";
    const [m, e] = Math.abs(x).toExponential().split("e");
    const chiffres = m.replace(".", ""), exp = +e, decpt = exp + 1;
    if (decpt > 16 || decpt < -3)
      return signe + chiffres[0] + (chiffres.length > 1 ? "." + chiffres.slice(1) : "") + "e" + (exp < 0 ? "-" : "+") + String(Math.abs(exp)).padStart(2, "0");
    if (decpt <= 0) return signe + "0." + "0".repeat(-decpt) + chiffres;
    if (chiffres.length <= decpt) return signe + chiffres + "0".repeat(decpt - chiffres.length) + ".0";
    return signe + chiffres.slice(0, decpt) + "." + chiffres.slice(decpt);
  };
  const erreur = (classe, message) => ({ classe, message });
  const CHIFFRES = { 2: /^[01]+$/, 8: /^[0-7]+$/, 10: /^[0-9]+$/, 16: /^[0-9a-fA-F]+$/ };
  const PREFIXE = { 2: /^0[bB]/, 8: /^0[oO]/, 16: /^0[xX]/ };
  // int(texte, base) de Python (sans les espaces ni les soulignés, que les constructeurs ont déjà retirés).
  function pyInt(texte, base) {
    let t = texte.trim(), signe = 1n;   // int() ignore les espaces autour
    if (/^[+-]/.test(t)) { if (t[0] === "-") signe = -1n; t = t.slice(1); }
    if (PREFIXE[base]?.test(t)) t = t.slice(2);
    if (!CHIFFRES[base].test(t)) throw erreur("ValueError", `invalid literal for int() with base ${base}: ${pyStr(texte)}`);
    let n = 0n;
    for (const c of t) n = n * BigInt(base) + BigInt(parseInt(c, 16));
    return signe * n;
  }
  // float(texte) de Python.
  function pyFloatDe(texte) {
    const t = texte.trim();
    if (/^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(t)) return Number(t);
    const m = /^([+-]?)(inf|infinity|nan)$/i.exec(t);
    if (m) return /^nan$/i.test(m[2]) ? NaN : m[1] === "-" ? -Infinity : Infinity;
    throw erreur("ValueError", `could not convert string to float: ${pyStr(texte)}`);
  }

  // ---------- Les deux schémas : motifs recopiés de resolver.py ----------
  const TS = /^(?:[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{4}-[0-9][0-9]?-[0-9][0-9]?(?:[Tt]|[ \t]+)[0-9][0-9]?:[0-9]{2}:[0-9]{2}(?:\.[0-9]*)?(?:[ \t]*(?:Z|[-+][0-9][0-9]?(?::[0-9]{2})?))?)$/;
  const TS_GROUPES = /^(?<an>[0-9]{4})-(?<mois>[0-9][0-9]?)-(?<jour>[0-9][0-9]?)(?:(?:[Tt]|[ \t]+)(?<h>[0-9][0-9]?):(?<min>[0-9]{2}):(?<s>[0-9]{2})(?:\.(?<fraction>[0-9]*))?(?:[ \t]*(?<tz>Z|(?<signe>[-+])(?<tzh>[0-9][0-9]?)(?::(?<tzm>[0-9]{2}))?))?)?$/;
  const NUL = /^(?:~|null|Null|NULL|)$/;
  const SCHEMAS = {
    "1.1": {
      nom: "YAML 1.1", analyseur: "PyYAML 6.0.2",
      motifs: [
        ["bool", /^(?:yes|Yes|YES|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF)$/, "yYnNtTfFoO"],
        ["float", /^(?:[-+]?(?:[0-9][0-9_]*)\.[0-9_]*(?:[eE][-+][0-9]+)?|\.[0-9][0-9_]*(?:[eE][-+][0-9]+)?|[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+\.[0-9_]*|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))$/, "-+0123456789."],
        ["int", /^(?:[-+]?0b[0-1_]+|[-+]?0[0-7_]+|[-+]?(?:0|[1-9][0-9_]*)|[-+]?0x[0-9a-fA-F_]+|[-+]?[1-9][0-9_]*(?::[0-5]?[0-9])+)$/, "-+0123456789"],
        ["merge", /^<<$/, "<"], ["null", NUL, "~nN"], ["timestamp", TS, "0123456789"], ["value", /^=$/, "="],
      ],
      booleens: { yes: true, no: false, true: true, false: false, on: true, off: false },
    },
    "1.2": {
      nom: "YAML 1.2", analyseur: "ruamel.yaml 0.18.10",
      motifs: [
        ["bool", /^(?:true|True|TRUE|false|False|FALSE)$/, "tTfF"],
        ["float", /^(?:[-+]?(?:[0-9][0-9_]*)\.[0-9_]*(?:[eE][-+]?[0-9]+)?|[-+]?(?:[0-9][0-9_]*)(?:[eE][-+]?[0-9]+)|[-+]?\.[0-9_]+(?:[eE][-+][0-9]+)?|[-+]?\.(?:inf|Inf|INF)|\.(?:nan|NaN|NAN))$/, "-+0123456789."],
        ["int", /^(?:[-+]?0b[0-1_]+|[-+]?0o?[0-7_]+|[-+]?[0-9_]+|[-+]?0x[0-9a-fA-F_]+)$/, "-+0123456789"],
        ["merge", /^<<$/, "<"], ["null", NUL, "~nN"], ["timestamp", TS, "0123456789"], ["value", /^=$/, "="],
      ],
      // ruamel.yaml garde la table de 1.1, y et n compris, pour les étiquettes explicites (!!bool y).
      booleens: { yes: true, no: false, y: true, n: false, true: true, false: false, on: true, off: false },
    },
  };
  const VERSIONS = ["1.1", "1.2"];

  // Le type que le motif donne au texte d'un scalaire nu (« str » si aucun motif ne le reconnaît).
  function resoudre(texte, version) {
    for (const [tag, motif, premiers] of SCHEMAS[version].motifs) {
      const candidat = texte === "" ? premiers === "~nN" : premiers.includes(texte[0]);   // le premier caractère désigne les motifs à essayer
      if (candidat && motif.test(texte)) return tag;
    }
    return "str";
  }

  // ---------- Les constructeurs : de constructor.py ----------
  function construireInt(texte, version) {
    let v = texte.replace(/_/g, "");
    let signe = 1n;
    if (v[0] === undefined) throw erreur("IndexError", "string index out of range");
    if (v[0] === "-") signe = -1n;
    if (v[0] === "+" || v[0] === "-") v = v.slice(1);
    if (v === "0") return { valeur: 0n, branche: "zero" };
    if (v.startsWith("0b")) return { valeur: signe * pyInt(v.slice(2), 2), branche: "binaire" };
    if (v.startsWith("0x")) return { valeur: signe * pyInt(v.slice(2), 16), branche: "hexa" };
    if (version === "1.2") {
      if (v.startsWith("0o")) return { valeur: signe * pyInt(v.slice(2), 8), branche: "octal-0o" };
      return { valeur: signe * pyInt(v, 10), branche: "decimal" };
    }
    if (v === "") throw erreur("IndexError", "string index out of range");   // PyYAML lit v[0] sans regarder
    if (v[0] === "0") return { valeur: signe * pyInt(v, 8), branche: "octal-0" };
    if (v.includes(":")) {
      const chiffres = v.split(":").map(p => pyInt(p, 10)).reverse();
      let base = 1n, somme = 0n;
      for (const c of chiffres) { somme += c * base; base *= 60n; }
      return { valeur: signe * somme, branche: "sexagesimal" };
    }
    return { valeur: signe * pyInt(v, 10), branche: "decimal" };
  }
  function construireFloat(texte, version) {
    let v = texte.replace(/_/g, "").toLowerCase();
    let signe = 1;
    if (v[0] === undefined) throw erreur("IndexError", "string index out of range");
    if (v[0] === "-") signe = -1;
    if (v[0] === "+" || v[0] === "-") v = v.slice(1);
    if (v === ".inf") return { valeur: signe * Infinity, branche: "inf" };
    if (v === ".nan") return { valeur: NaN, branche: "nan" };
    if (version === "1.1" && v.includes(":")) {
      const chiffres = v.split(":").map(pyFloatDe).reverse();
      let base = 1, somme = 0.0;
      for (const c of chiffres) { somme += c * base; base *= 60; }
      return { valeur: signe * somme, branche: "sexagesimal" };
    }
    return { valeur: signe * pyFloatDe(v), branche: /e/.test(v) ? "exposant" : "decimal" };
  }
  const iso = (n, largeur = 2) => String(n).padStart(largeur, "0");
  const joursDuMois = (a, m) => [31, a % 4 === 0 && (a % 100 !== 0 || a % 400 === 0) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
  function construireDate(texte) {
    const g = TS_GROUPES.exec(texte).groups;
    const an = +g.an, mois = +g.mois, jour = +g.jour;
    // Les deux analyseurs créent le fuseau avant la date : son erreur passerait la première.
    if (g.signe && (+g.tzh * 60 + +(g.tzm || 0)) >= 24 * 60) throw { limite: "un décalage horaire de 24 heures ou plus, que Python refuse avec un message que le simulateur ne reproduit pas" };
    if (an < 1) throw erreur("ValueError", `year ${an} is out of range`);
    if (mois < 1 || mois > 12) throw erreur("ValueError", "month must be in 1..12");
    if (jour < 1 || jour > joursDuMois(an, mois)) throw erreur("ValueError", "day is out of range for month");
    const date = `${iso(an, 4)}-${iso(mois)}-${iso(jour)}`;
    if (g.h === undefined) return { t: "date", v: date, repr: `datetime.date(${an}, ${mois}, ${jour})` };
    const h = +g.h, min = +g.min, s = +g.s;
    if (h > 23) throw erreur("ValueError", "hour must be in 0..23");
    if (min > 59) throw erreur("ValueError", "minute must be in 0..59");
    if (s > 59) throw erreur("ValueError", "second must be in 0..59");
    if (g.fraction && g.fraction.length > 6)
      throw { limite: "une fraction de seconde de plus de six chiffres : PyYAML la tronque, ruamel.yaml l’arrondit, et le simulateur ne les départage pas" };
    let decalage = "";
    if (g.signe) {
      const minutes = (+g.tzh * 60 + +(g.tzm || 0)) * (g.signe === "-" ? -1 : 1);
      decalage = (minutes < 0 ? "-" : "+") + iso(Math.floor(Math.abs(minutes) / 60)) + ":" + iso(Math.abs(minutes) % 60);
    } else if (g.tz) decalage = "+00:00";
    const fraction = g.fraction ? "." + g.fraction.padEnd(6, "0") : "";
    const heure = `${iso(h)}:${iso(min)}:${iso(s)}${+g.fraction ? fraction : ""}`;
    return { t: "datetime", v: `${date}T${heure}${decalage}`, repr: null };
  }

  // Construit la valeur d'un scalaire dont le motif a désigné `tag` (ou que l'étiquette impose).
  function construire(tag, texte, version) {
    switch (tag) {
      case "str": return { noeud: { t: "str", v: texte } };
      case "null": return { noeud: { t: "null" } };
      case "bool": {
        const v = SCHEMAS[version].booleens[texte.toLowerCase()];
        if (v === undefined) throw erreur("KeyError", pyStr(texte.toLowerCase()));
        return { noeud: { t: "bool", v } };
      }
      case "int": { const r = construireInt(texte, version); return { noeud: { t: "int", v: r.valeur }, branche: r.branche }; }
      case "float": { const r = construireFloat(texte, version); return { noeud: { t: "float", v: r.valeur }, branche: r.branche }; }
      case "timestamp": return { noeud: construireDate(texte) };
      default: throw erreur("ConstructorError", `could not determine a constructor for the tag 'tag:yaml.org,2002:${tag}'`);
    }
  }

  // ---------- La lecture du texte : scalaires, listes plates, petits documents ----------
  const ESCAPES = { 0: "\0", a: "\x07", b: "\b", t: "\t", "\t": "\t", n: "\n", v: "\v", f: "\f", r: "\r", e: "\x1b", " ": " ", '"': '"', "\\": "\\", "/": "/", N: "\x85", _: "\xa0", L: "\u2028", P: "\u2029" };
  const HEX = { x: 2, u: 4, U: 8 };
  // ruamel.yaml écrit « hexdecimal » là où PyYAML écrit « hexadecimal » : `variantes` garde le texte de chaque version.
  const refus = (classe, message) => {
    const e = erreur(classe, message);
    if (/hexadecimal/.test(message)) e.variantes = { "1.2": message.replace("hexadecimal", "hexdecimal") };
    throw e;
  };
  const limite = texte => { throw { limite: texte }; };
  const car = c => c === "\t" ? "\\t" : c;

  // Lit un scalaire entre guillemets au début de t ; rend { texte, reste }.
  function lireEntreGuillemets(t) {
    const q = t[0];
    let i = 1, sortie = "";
    for (;;) {
      if (i >= t.length) refus("ScannerError", "found unexpected end of stream");
      const c = t[i];
      if (q === "'") {
        if (c === "'") { if (t[i + 1] === "'") { sortie += "'"; i += 2; continue; } return { texte: sortie, reste: t.slice(i + 1) }; }
        sortie += c; i++;
      } else {
        if (c === '"') return { texte: sortie, reste: t.slice(i + 1) };
        if (c !== "\\") { sortie += c; i++; continue; }
        const e = t[i + 1];
        if (e === undefined) refus("ScannerError", "found unexpected end of stream");
        if (e in ESCAPES) { sortie += ESCAPES[e]; i += 2; }
        else if (e in HEX) {
          const n = HEX[e], code = t.slice(i + 2, i + 2 + n);
          const faux = [...code].findIndex(x => !/[0-9a-fA-F]/.test(x));
          if (code.length < n || faux >= 0) refus("ScannerError", `expected escape sequence of ${n} hexadecimal numbers, but found ${pyStr(faux >= 0 ? code[faux] : t[i + 2 + code.length] ?? "\n")}`);
          const cp = parseInt(code, 16);
          if (cp > 0x10ffff) limite("un code de caractère hors de la plage Unicode (\\U…), que Python refuse par une erreur que le simulateur ne reproduit pas");
          sortie += String.fromCodePoint(cp); i += 2 + n;
        } else refus("ScannerError", `found unknown escape character ${pyStr(e)}`);
      }
    }
  }
  const TAGS_LUS = new Set(["str", "int", "float", "bool", "null"]);

  // Lit ce qui suit « clé: » (contexte "bloc") ou « - » (contexte "item") : un scalaire, vu comme l'analyseur le lit.
  // Rend { style: "nu" | "simples" | "doubles", texte, etiquette }, ou lève une erreur, ou une limitation.
  function lireScalaire(source, contexte = "bloc") {
    if (PRINTABLE_NON.test(source) || /[\x85\u2028\u2029]/.test(source)) limite("un caractère de contrôle, un caractère non imprimable ou un saut de ligne dans le texte");
    let t = source.replace(/^ +/, "");
    if (t.startsWith("\t")) refus("ScannerError", "found character '\\t' that cannot start any token");
    if (t === "" || t[0] === "#") return { style: "nu", texte: "", etiquette: null };
    let etiquette = null;
    if (t[0] === "!") {
      const m = /^!!([A-Za-z]+)(?= |$)/.exec(t);
      if (!m || !TAGS_LUS.has(m[1])) limite("une étiquette autre que !!str, !!int, !!float, !!bool, !!null");
      etiquette = m[1];
      t = t.slice(m[0].length).replace(/^ +/, "");
      if (t === "" || t[0] === "#") return { style: "nu", texte: "", etiquette };
      if (t[0] === "!") {
        if (!/^!![A-Za-z]+(?= |$)/.test(t)) limite("une seconde étiquette mal formée");
        refus("ParserError", "expected <block end>, but found '<tag>'");
      }
      if (t[0] === "," || t[0] === "]" || t[0] === "}") refus("ParserError", `expected <block end>, but found '${t[0]}'`);
    }
    const c = t[0];
    if (c === "'" || c === '"') {
      const lu = lireEntreGuillemets(t);
      const reste = lu.reste.replace(/^ +/, "");
      if (reste.startsWith("\t")) refus("ScannerError", "found character '\\t' that cannot start any token");
      if (reste !== "" && reste[0] !== "#") {
        if (/^['"]/.test(reste)) { lireEntreGuillemets(reste); refus("ParserError", "expected <block end>, but found '<scalar>'"); }
        if (/^[^\s,\[\]{}&*!|>%@`:?'"-]/.test(reste) && !/:(?: |$)/.test(reste)) refus("ParserError", "expected <block end>, but found '<scalar>'");
        limite("un texte après la fermeture des guillemets");
      }
      return { style: c === "'" ? "simples" : "doubles", texte: lu.texte, etiquette };
    }
    if (c === "[" || c === "{") limite("un flux (liste ou mapping entre crochets ou accolades) à cet endroit");
    if (c === "&" || c === "*") limite("une ancre ou un alias (& ou *)");
    if (c === "|" || c === ">") limite("un bloc multiligne (| ou >)");
    if (c === "%" || c === "@" || c === "`") refus("ScannerError", `found character '${c}' that cannot start any token`);
    if (c === "," || c === "]" || c === "}") refus("ParserError", `expected the node content, but found '${c}'`);
    if (c === "-" && (t.length === 1 || t[1] === " " || t[1] === "\t")) {
      if (contexte === "item") limite("une liste imbriquée");
      refus("ScannerError", "sequence entries are not allowed here");
    }
    if (c === "?" && (t.length === 1 || t[1] === " " || t[1] === "\t")) {
      if (contexte === "item") limite("une clé complexe (?)");
      refus("ScannerError", "mapping keys are not allowed here");
    }
    // Un scalaire nu : il s'arrête à « espace + # » ; « : » suivi d'une espace en fait une clé.
    let fin = t.length;
    for (let i = 0; i < t.length; i++) {
      if (t[i] === "\t") refus("ScannerError", "found character '\\t' that cannot start any token");
      if (t[i] === "#" && i > 0 && t[i - 1] === " ") { fin = i; break; }
      if (t[i] === ":" && (i + 1 === t.length || t[i + 1] === " " || t[i + 1] === "\t")) {
        if (contexte === "item") limite("un mapping dans un élément de liste");
        refus("ScannerError", "mapping values are not allowed here");
      }
    }
    return { style: "nu", texte: t.slice(0, fin).replace(/ +$/, ""), etiquette };
  }

  // Un flux plat : [a, "b", 3] ; rend les éléments, chacun un scalaire lu.
  function lireFlux(source) {
    if (PRINTABLE_NON.test(source)) limite("un caractère de contrôle ou non imprimable dans le texte");
    let t = source.replace(/^ +/, "");
    let i = 1;
    const items = [];
    let attendu = true;           // un élément est attendu (début, ou après une virgule)
    for (;;) {
      while (t[i] === " ") i++;
      if (i >= t.length) limite("un flux qui n'est pas refermé sur la même ligne");
      const c = t[i];
      if (c === "]") {
        i++;
        const reste = t.slice(i).replace(/^ +/, "");
        if (reste !== "" && reste[0] !== "#") limite("un texte après la fermeture du flux");
        return items;
      }
      if (c === ",") {
        if (attendu) refus("ParserError", "expected the node content, but found ','");
        attendu = true; i++; continue;
      }
      if (!attendu) limite("un flux mal formé");
      if (c === "[" || c === "{" || c === "}") limite("un flux imbriqué");
      if (c === ":") limite("un élément de flux qui commence par « : »");
      if (c === "&" || c === "*" || c === "!" || c === "|" || c === ">" || c === "%" || c === "@" || c === "`" || c === "#" || c === "\t")
        limite(`un élément de flux qui commence par « ${car(c)} »`);
      if (c === "'" || c === '"') {
        const lu = lireEntreGuillemets(t.slice(i));
        items.push({ style: c === "'" ? "simples" : "doubles", texte: lu.texte, etiquette: null });
        i = t.length - lu.reste.length;
      } else {
        let j = i;
        while (j < t.length && t[j] !== "," && t[j] !== "]") {
          if (t[j] === "[" || t[j] === "{" || t[j] === "}" || t[j] === "\t") limite("un élément de flux avec un crochet, une accolade ou une tabulation");
          if (t[j] === ":" && (j + 1 === t.length || " ,]".includes(t[j + 1]))) limite("un élément de flux qui contient « : » suivi d'une espace, d'une virgule ou de la fin");
          if (t[j] === "?") limite("un élément de flux qui contient « ? »");
          if (t[j] === "#" && t[j - 1] === " ") limite("un commentaire dans un flux");
          j++;
        }
        const brut = t.slice(i, j).replace(/ +$/, "");
        if (/^-(?: |$)/.test(brut)) limite("un élément de flux qui commence par « - »");
        items.push({ style: "nu", texte: brut, etiquette: null });
        i = j;
      }
      attendu = false;
    }
  }

  // Analyse syntaxique d'un petit document : { paires: [{ cle, valeur }] } où valeur est
  // { genre: "scalaire", lu } ou { genre: "liste", items: [lu] }.
  function analyserDocument(texte) {
    try { return analyserLignes(texte); } catch (e) {
      // Un texte entre guillemets non fermé sur sa ligne continue à la ligne suivante : le simulateur ne lit qu'une ligne.
      if (e.message === "found unexpected end of stream") limite("des guillemets non refermés sur leur ligne : le texte continue sur la ligne suivante");
      throw e;
    }
  }
  function analyserLignes(texte) {
    if (PRINTABLE_NON.test(texte.replace(/\r\n?/g, "\n").replace(/\n/g, " ")) || /[\x85\u2028\u2029]/.test(texte))
      limite("un caractère de contrôle, un caractère non imprimable ou un saut de ligne inhabituel dans le texte");
    const lignes = texte.replace(/\r\n?/g, "\n").split("\n");
    const paires = [];
    let debut = false, courante = null;
    for (const brut of lignes) {
      const ligne = brut.replace(/ +$/, "");
      const vide = ligne.trim() === "";
      if (vide || /^\s*#/.test(ligne)) continue;
      if (/^%/.test(ligne)) limite("une directive (%YAML…) : PyYAML l’ignore, ruamel.yaml en tient compte, et le simulateur ne les départage pas");
      if (/^---(?: |$)/.test(ligne)) {
        if (debut || paires.length) limite("plusieurs documents dans un fichier");
        debut = true;
        const reste = ligne.slice(3).trim();
        if (reste !== "" && !reste.startsWith("#")) limite("un contenu sur la ligne de début de document");
        continue;
      }
      if (/^\.\.\.(?: |$)/.test(ligne)) limite("une fin de document (...)");
      if (/^\s*-(?: |$)/.test(ligne)) {
        const item = /^(\s*)-(?: +(.*))?$/.exec(ligne);
        if (courante && courante.attendListe) {
          if (courante.indent === null) courante.indent = item[1].length;
          else if (courante.indent !== item[1].length) limite("des éléments de liste à des indentations différentes");
          courante.valeur.items.push(lireScalaire(item[2] ?? "", "item"));
          continue;
        }
        limite(paires.length ? "une liste dont la clé n'est pas la ligne précédente" : "un document dont la racine est une liste");
      }
      if (/^\s/.test(ligne)) limite("une ligne indentée : mapping imbriqué ou scalaire sur plusieurs lignes");
      // Une ligne « clé: valeur ».
      if (/^['"]/.test(ligne)) limite("une clé entre guillemets");
      if (/^[\[\]{}&*!|>%@`,?:-]/.test(ligne) && !/^[-?:][^ \t]/.test(ligne)) limite(`une ligne qui commence par « ${ligne[0]} »`);
      const m = /:(?: |$)/.exec(ligne);
      if (!m) limite("une ligne sans « : », qui ne serait pas une clé");
      const cle = ligne.slice(0, m.index).replace(/ +$/, "");
      if (cle.includes(" #") || cle.includes("\t")) limite("une clé qui contient un commentaire ou une tabulation");
      if (cle === "<<" || cle === "=") limite("une clé « << » ou « = », réservée par YAML 1.1");
      const lu = lireScalaire(cle, "item");
      if (lu.style !== "nu" || lu.etiquette) limite("une clé étiquetée ou entre guillemets");
      const reste = ligne.slice(m.index + 1).replace(/^ +/, "");
      let valeur;
      if (reste.startsWith("[")) valeur = { genre: "liste", items: lireFlux(reste), attendListe: false };
      else {
        const sc = lireScalaire(reste, "bloc");
        const sansValeur = sc.style === "nu" && sc.texte === "" && !sc.etiquette;
        valeur = sansValeur ? { genre: "liste", items: [], attendListe: true, vide: true } : { genre: "scalaire", lu: sc };
      }
      courante = { cle: lu, valeur, indent: null, attendListe: valeur.attendListe };
      paires.push(courante);
    }
    return paires.map(p => ({ cle: p.cle, valeur: p.valeur.genre === "liste" && p.valeur.vide && !p.valeur.items.length
      ? { genre: "scalaire", lu: { style: "nu", texte: "", etiquette: null } } : p.valeur }));
  }

  // ---------- Lecture par une version : du texte lu au nœud typé ----------
  // La règle qui a décidé : { genre, tag, branche, etiquette }.
  function lireNoeud(lu, version) {
    if (lu.etiquette) {
      const r = construire(lu.etiquette, lu.texte, version);
      return { noeud: r.noeud, regle: { genre: "etiquette", tag: lu.etiquette, branche: r.branche, etiquette: lu.etiquette, style: lu.style } };
    }
    if (lu.style !== "nu") return { noeud: { t: "str", v: lu.texte }, regle: { genre: "guillemets", tag: "str", style: lu.style } };
    const tag = resoudre(lu.texte, version);
    const r = construire(tag, lu.texte, version);
    return { noeud: r.noeud, regle: { genre: tag === "str" ? "defaut" : lu.texte === "" ? "vide" : "motif", tag, branche: r.branche } };
  }
  const erreurDe = e => { if (e && e.classe) return e; throw e; };

  // ---------- Python en bout de chaîne : repr et json.dumps ----------
  const reprNoeud = n => {
    switch (n.t) {
      case "str": return pyStr(n.v);
      case "int": return n.v.toString();
      case "float": return pyFloat(n.v);
      case "bool": return n.v ? "True" : "False";
      case "null": return "None";
      case "date": return n.repr;
      case "datetime": return `datetime ${n.v}`;
      case "list": return "[" + n.v.map(reprNoeud).join(", ") + "]";
      case "dict": return "{" + n.v.map(([k, v]) => reprNoeud(k) + ": " + reprNoeud(v)).join(", ") + "}";
    }
  };
  const JSON_ECHAPPES = { '"': '\\"', "\\": "\\\\", "\n": "\\n", "\r": "\\r", "\t": "\\t", "\b": "\\b", "\f": "\\f" };
  const jsonChaine = s => '"' + s.replace(/["\\\n\r\t\b\f]|[\x00-\x1f]/g, c => JSON_ECHAPPES[c] ?? "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0")) + '"';
  const jsonFloat = x => x !== x ? "NaN" : x === Infinity ? "Infinity" : x === -Infinity ? "-Infinity" : pyFloat(x);
  const NOM_TYPE_PYTHON = { date: "date", datetime: "datetime" };
  const NOM_TYPE_PYTHON_CLE = { date: "datetime.date", datetime: "datetime.datetime" };
  // json.dumps(valeur, ensure_ascii=False[, indent=2]) ; lève { classe: "TypeError", message } pour une date.
  function jsonDumps(n, indent = null, niveau = 0) {
    const retrait = k => indent === null ? "" : "\n" + " ".repeat(indent * k);
    switch (n.t) {
      case "str": return jsonChaine(n.v);
      case "int": return n.v.toString();
      case "float": return jsonFloat(n.v);
      case "bool": return n.v ? "true" : "false";
      case "null": return "null";
      case "date": case "datetime": throw erreur("TypeError", `Object of type ${NOM_TYPE_PYTHON[n.t]} is not JSON serializable`);
      case "list": {
        if (!n.v.length) return "[]";
        return "[" + n.v.map(x => retrait(niveau + 1) + jsonDumps(x, indent, niveau + 1)).join(indent === null ? ", " : ",") + retrait(niveau) + "]";
      }
      case "dict": {
        if (!n.v.length) return "{}";
        const morceaux = n.v.map(([k, v]) => {
          let cle;
          switch (k.t) {
            case "str": cle = k.v; break;
            case "int": cle = k.v.toString(); break;
            case "float": cle = jsonFloat(k.v); break;
            case "bool": cle = k.v ? "true" : "false"; break;
            case "null": cle = "null"; break;
            default: throw erreur("TypeError", `keys must be str, int, float, bool or None, not ${NOM_TYPE_PYTHON_CLE[k.t]}`);
          }
          return retrait(niveau + 1) + jsonChaine(cle) + ": " + jsonDumps(v, indent, niveau + 1);
        });
        return "{" + morceaux.join(indent === null ? ", " : ",") + retrait(niveau) + "}";
      }
    }
  }
  const json = (n, indent) => { try { return { texte: jsonDumps(n, indent) }; } catch (e) { return { erreur: erreurDe(e) }; } };

  // L'arbre canonique, comparé aux analyseurs réels par verifier-analyseurs.js.
  function arbre(n) {
    switch (n.t) {
      case "int": return ["int", n.v.toString()];
      case "float": return ["float", pyFloat(n.v)];
      case "bool": return ["bool", n.v];
      case "null": return ["null"];
      case "list": return ["list", n.v.map(arbre)];
      case "dict": return ["dict", n.v.map(([k, v]) => [arbre(k), arbre(v)])];
      default: return [n.t, n.v];
    }
  }
  // Une clé de dict Python : deux clés égales (1 et 1.0 et True) se confondent.
  function cleCanonique(n) {
    switch (n.t) {
      case "bool": return "n:" + (n.v ? 1 : 0);
      case "int": return "n:" + n.v;
      case "float": return Number.isFinite(n.v) && Number.isInteger(n.v) ? "n:" + BigInt(n.v) : n.v !== n.v ? "nan:" + Math.random() : "f:" + pyFloat(n.v);
      default: return n.t + ":" + (n.v ?? "");
    }
  }

  // ---------- Les simulations ----------
  // Un scalaire : écrit après « clé: », lu par chaque version.
  function simulerScalaire(texte) {
    const r = { entree: { mode: "scalaire", texte }, lecture: null, erreurSyntaxe: null, limites: [], versions: {} };
    try {
      if (/^ *[\[{]/.test(texte)) limite("une liste ou un mapping : choisissez le mode « document » pour une liste plate");
      r.lecture = lireScalaire(texte, "bloc");
    } catch (e) {
      if (e.limite) { r.limites.push(e.limite); return r; }
      r.erreurSyntaxe = erreurDe(e); return r;
    }
    for (const v of VERSIONS) {
      try {
        const lu = lireNoeud(r.lecture, v);
        r.versions[v] = { version: v, ok: true, noeud: lu.noeud, regle: lu.regle, repr: reprNoeud(lu.noeud), json: json(lu.noeud), arbre: arbre(lu.noeud) };
      } catch (e) {
        if (e.limite) { r.limites.push(e.limite); r.versions = {}; return r; }
        r.versions[v] = { version: v, ok: false, erreur: erreurDe(e) };
      }
    }
    return r;
  }

  // Un petit document : les clés sont des scalaires comme les autres.
  function simulerDocument(texte) {
    const r = { entree: { mode: "document", texte }, erreurSyntaxe: null, limites: [], versions: {}, paires: null };
    let paires;
    try { paires = analyserDocument(texte); } catch (e) {
      if (e.limite) { r.limites.push(e.limite); return r; }
      r.erreurSyntaxe = erreurDe(e); return r;
    }
    r.paires = paires;
    for (const v of VERSIONS) {
      try {
        // PyYAML et ruamel.yaml construisent d'abord les clés et les scalaires, puis le contenu des listes.
        const lignes = [], vus = new Map(), ecart = [];
        for (const p of paires) {
          const cle = lireNoeud(p.cle, v);
          const ligne = { cle, valeur: null, noeudCle: cle.noeud };
          const canon = cleCanonique(cle.noeud);
          // ruamel.yaml construit la valeur d'un scalaire avant de chercher le doublon (une liste, après).
          if (p.valeur.genre === "scalaire") ligne.valeur = { genre: "scalaire", ...lireNoeud(p.valeur.lu, v) };
          if (v === "1.2" && vus.has(canon)) throw erreur("DuplicateKeyError", `found duplicate key ${reprNoeud(cle.noeud)}`);
          if (vus.has(canon)) ligne.remplace = vus.get(canon);   // PyYAML : la dernière valeur l'emporte
          vus.set(canon, ligne);
          if (p.valeur.genre !== "scalaire") ecart.push([ligne, p.valeur]);
          lignes.push(ligne);
        }
        for (const [ligne, valeur] of ecart) ligne.valeur = { genre: "liste", items: valeur.items.map(lu => lireNoeud(lu, v)) };
        // Le dict de Python : une clé répétée garde sa place et reçoit la dernière valeur.
        const dict = [];
        const index = new Map();
        for (const l of lignes) {
          const canon = cleCanonique(l.noeudCle);
          const valeur = l.valeur.genre === "scalaire" ? l.valeur.noeud : { t: "list", v: l.valeur.items.map(i => i.noeud) };
          if (index.has(canon)) dict[index.get(canon)][1] = valeur;
          else { index.set(canon, dict.length); dict.push([l.noeudCle, valeur]); }
        }
        const racine = paires.length ? { t: "dict", v: dict } : { t: "null" };
        r.versions[v] = {
          version: v, ok: true, lignes, noeud: racine, repr: reprNoeud(racine), json: json(racine), arbre: arbre(racine),
          doublons: lignes.filter(l => l.remplace).map(l => l.noeudCle),
        };
      } catch (e) {
        if (e.limite) { r.limites.push(e.limite); r.versions = {}; return r; }
        r.versions[v] = { version: v, ok: false, erreur: erreurDe(e) };
      }
    }
    return r;
  }
  const simuler = e => e.mode === "document" ? simulerDocument(e.texte) : simulerScalaire(e.texte);

  // ---------- Explications : calculées à partir du résultat ----------
  const NOM_TYPE = { str: "chaîne", int: "entier", float: "flottant", bool: "booléen", null: "nul", date: "date", datetime: "date et heure", list: "liste", dict: "mapping" };
  const SCHEMA_NOM = v => `${SCHEMAS[v].nom} (${SCHEMAS[v].analyseur.split(" ")[0]})`;
  const guil = s => `« ${s} »`;
  const code = s => "`" + s + "`";

  // La règle de la version, en une phrase, d'après le résultat.
  const MOTIFS = {
    bool: { "1.1": "booléen de YAML 1.1 : yes, no, on, off, true, false, en minuscules, capitalisés ou en capitales",
            "1.2": "booléen du schéma de base 1.2 : seulement true et false, en minuscules, capitalisés ou en capitales" },
    null: { "1.1": "null : null, Null, NULL, ~ ou rien", "1.2": "null : null, Null, NULL, ~ ou rien" },
    timestamp: { "1.1": "date : AAAA-MM-JJ, avec une heure et un fuseau facultatifs", "1.2": "date : AAAA-MM-JJ, avec une heure et un fuseau facultatifs" },
  };
  const BRANCHES_INT = {
    zero: "entier : zéro", decimal: "entier décimal : des chiffres, zéros initiaux compris",
    "octal-0": "entier octal de YAML 1.1 : un 0, puis des chiffres de 0 à 7, lus en base 8",
    "octal-0o": "entier octal de YAML 1.2 : 0o, puis des chiffres de 0 à 7, lus en base 8",
    hexa: "entier hexadécimal : 0x, puis des chiffres hexadécimaux", binaire: "entier binaire : 0b, puis des 0 et des 1",
    sexagesimal: "entier sexagésimal de YAML 1.1 : des nombres séparés par « : », lus en base 60",
  };
  const BRANCHES_FLOAT = {
    decimal: "flottant : des chiffres et un point", exposant: "flottant avec exposant",
    inf: "flottant infini : .inf", nan: "flottant « pas un nombre » : .nan",
    sexagesimal: "flottant sexagésimal de YAML 1.1 : des nombres séparés par « : », avec une partie décimale",
  };
  function phraseRegle(res) {
    const g = res.regle;
    if (g.genre === "guillemets") return g.style === "simples" ? "entre guillemets simples : une chaîne, aucun motif n’est essayé" : "entre guillemets doubles : une chaîne, aucun motif n’est essayé (les séquences \\ sont décodées)";
    if (g.genre === "etiquette") return `étiquette !!${g.etiquette} : le type est imposé, aucun motif n’est essayé`;
    if (g.genre === "vide") return "valeur vide : le motif null la reconnaît";
    if (g.genre === "defaut") return `aucun motif de ${SCHEMAS[res.version].nom} ne reconnaît ce texte : chaîne, le type par défaut`;
    if (g.tag === "int") return `motif ${BRANCHES_INT[g.branche]}`;
    if (g.tag === "float") return `motif ${BRANCHES_FLOAT[g.branche]}`;
    return `motif ${MOTIFS[g.tag][res.version]}`;
  }
  const BRANCHES_COURT = { zero: "zéro", decimal: "décimal", "octal-0": "octal", "octal-0o": "octal 0o", hexa: "hexadécimal", binaire: "binaire", sexagesimal: "base 60", exposant: "exposant", inf: "infini", nan: "nan" };
  const COURT = { bool: "booléen", null: "null", timestamp: "date", int: "entier", float: "flottant" };
  function regleCourte(res) {
    const g = res.regle;
    if (g.genre === "guillemets") return "guillemets";
    if (g.genre === "etiquette") return `étiquette !!${g.etiquette}`;
    if (g.genre === "vide") return "vide";
    if (g.genre === "defaut") return "chaîne par défaut";
    return `motif ${COURT[g.tag]}${g.branche && g.tag !== "bool" ? " " + BRANCHES_COURT[g.branche] : ""}`;
  }
  const valeurTexte = res => `${NOM_TYPE[res.noeud.t]} ${res.repr}`;

  // Là où un analyseur s'écarte de sa spécification : le simulateur suit l'analyseur, et le dit.
  function ecartsDeSpecification(texte, resultats) {
    const notes = [];
    const r11 = resultats["1.1"], r12 = resultats["1.2"];
    if (r11?.ok && r11.regle.genre === "defaut" && /^[yYnN]$/.test(texte))
      notes.push(`PyYAML s’écarte ici de la spécification 1.1, qui range ${texte} parmi les booléens : il lit une chaîne.`);
    if (r11?.ok && r11.regle.genre === "defaut" && /^[-+]\.[0-9]/.test(texte))
      notes.push(`PyYAML ne reconnaît pas ${texte} comme flottant : son motif exige un chiffre avant le point quand il y a un signe.`);
    if (r11?.ok && r11.regle.genre === "defaut" && /^[-+]?[0-9][0-9_]*(?:\.[0-9_]*)?[eE][-+]?[0-9]+$/.test(texte) && r12?.ok && r12.noeud.t === "float")
      notes.push("PyYAML exige un point et un signe dans l’exposant (1.5e+3) : sans eux, ce n’est pas un flottant.");
    if (r12?.ok && r12.regle.genre === "defaut" && /^[-+]?\.[0-9_]+[eE][0-9]/.test(texte))
      notes.push("ruamel.yaml exige un signe à l’exposant quand la mantisse commence par un point (.1e+3) ; le schéma de base 1.2 l’accepte sans signe.");
    if (r12?.ok && r12.regle.tag === "int" && (r12.regle.branche === "binaire" || /_/.test(texte)))
      notes.push("ruamel.yaml accepte ici 0b… et les soulignés (_), que le schéma de base de YAML 1.2 ne prévoit pas : le simulateur suit ruamel.yaml.");
    if (r12?.ok && r12.regle.tag === "timestamp")
      notes.push("Le schéma de base de YAML 1.2 n’a pas de type date ; ruamel.yaml en reconnaît pourtant une, comme PyYAML.");
    return notes;
  }
  const conseil = texte => `Pour une chaîne dans toutes les versions : "${texte.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}".`;

  // JSON : ce que json.dumps fait de chaque lecture (une phrase par résultat, les lectures identiques réunies).
  function phrasesJson(resultats) {
    const groupes = new Map();
    for (const v of VERSIONS) {
      const r = resultats[v];
      if (!r?.ok) continue;
      let phrase = null;
      if (r.json.erreur) {
        const e = r.json.erreur;
        phrase = `json.dumps échoue (${e.classe} : ${e.message})` + (/date/.test(e.message) && !/keys/.test(e.message) ? " ; un yq écrit en Go écrirait la chaîne, Python refuse" : "");
      } else if (/Infinity|NaN/.test(r.json.texte)) phrase = `Python écrit ${r.json.texte.match(/-?Infinity|NaN/)[0]}, que le format JSON n’admet pas (RFC 8259)`;
      if (phrase) groupes.set(phrase, [...(groupes.get(phrase) ?? []), v]);
    }
    return [...groupes].map(([phrase, versions]) => `JSON, ${versions.length > 1 ? "lectures 1.1 et 1.2" : "lecture " + versions[0]} : ${phrase}.`);
  }

  function expliquerScalaire(r) {
    const p = [], texte = r.entree.texte;
    if (r.limites.length) return r.limites.map(l => `Limitation du simulateur : ${l}.`);
    if (r.erreurSyntaxe) {
      p.push(`Les deux analyseurs refusent ce texte avant même de lui chercher un type : ${r.erreurSyntaxe.classe}, « ${r.erreurSyntaxe.message} ».`);
      p.push("Le texte écrit après « clé: » n’est pas un scalaire valide ; entre guillemets, il le devient souvent.");
      return p;
    }
    const a = r.versions["1.1"], b = r.versions["1.2"];
    const l = r.lecture;
    p.push(l.style === "nu" && !l.etiquette
      ? "Sans guillemets, YAML essaie les motifs du schéma dans l’ordre (booléen, flottant, entier, null, date) : le premier qui reconnaît le texte décide du type."
      : l.etiquette ? `Avec l’étiquette !!${l.etiquette}, le type est imposé : le texte est converti, sans chercher quel motif lui irait.`
        : `Entre guillemets ${l.style === "simples" ? "simples" : "doubles"}, le texte est une chaîne : aucun motif n’est essayé.`);
    for (const res of [a, b]) {
      if (res.ok) p.push(`${SCHEMA_NOM(res.version)} : ${phraseRegle(res)} → ${valeurTexte(res)}.`);
      else p.push(`${SCHEMA_NOM(res.version)} : ${res.regle ? "" : "le motif reconnaît le texte, mais "}la conversion échoue (${res.erreur.classe} : ${res.erreur.message}).`);
    }
    if (a.ok && b.ok) {
      if (JSON.stringify(a.arbre) === JSON.stringify(b.arbre) && a.noeud.t === b.noeud.t) p.push("Les deux versions lisent la même chose : ce texte ne dépend pas de la spécification.");
      else if (a.noeud.t !== b.noeud.t || a.repr !== b.repr)
        p.push(`Elles divergent : ${valeurTexte(a)} en 1.1, ${valeurTexte(b)} en 1.2. ${conseil(l.texte)}`);
    } else if (a.ok !== b.ok) {
      p.push(`Elles divergent : l’une lit le texte, l’autre le refuse. ${conseil(l.texte)}`);
    } else p.push("Les deux versions échouent de la même façon : le motif reconnaît la forme du texte, la conversion n’a pas de valeur à rendre.");
    p.push(...ecartsDeSpecification(l.texte, r.versions));
    p.push(...phrasesJson(r.versions));
    return p;
  }

  function expliquerDocument(r) {
    if (r.limites.length) return r.limites.map(l => `Limitation du simulateur : ${l}.`);
    const p = [];
    if (r.erreurSyntaxe) {
      p.push(`Les deux analyseurs refusent ce document avant de lui chercher un type : ${r.erreurSyntaxe.classe}, « ${r.erreurSyntaxe.message} ».`);
      return p;
    }
    const a = r.versions["1.1"], b = r.versions["1.2"];
    for (const res of [a, b]) if (!res.ok) p.push(`${SCHEMA_NOM(res.version)} : lecture refusée (${res.erreur.classe} : ${res.erreur.message}) ; le document entier est perdu, pas seulement la valeur fautive.`);
    if (a.ok && b.ok) {
      // Chaque endroit où les deux lectures divergent : clé ou valeur, avec la règle de chacune.
      const diffs = [];
      const dit = (x, y, lu, nom) => {
        if (x.noeud.t !== y.noeud.t || reprNoeud(x.noeud) !== reprNoeud(y.noeud))
          diffs.push(`${nom} (${guil(lu.texte)}) : ${reprNoeud(x.noeud)} en 1.1 (${regleCourte({ ...x, version: "1.1" })}), ${reprNoeud(y.noeud)} en 1.2 (${regleCourte({ ...y, version: "1.2" })})`);
      };
      r.paires.forEach((paire, i) => {
        const la = a.lignes[i], lb = b.lignes[i];
        dit(la.cle, lb.cle, paire.cle, `clé ${paire.cle.texte}`);
        if (paire.valeur.genre === "scalaire") dit(la.valeur, lb.valeur, paire.valeur.lu, paire.cle.texte);
        else la.valeur.items.forEach((x, k) => dit(x, lb.valeur.items[k], paire.valeur.items[k], `${paire.cle.texte}[${k}]`));
      });
      if (!diffs.length) p.push("Les deux versions lisent le même arbre : ce document ne dépend pas de la spécification.");
      else {
        p.push(`Les deux versions divergent en ${diffs.length} endroit${diffs.length > 1 ? "s" : ""} : ${diffs.slice(0, 3).join(" ; ")}${diffs.length > 3 ? " ; …" : ""}.`);
        p.push("Des guillemets gardent une chaîne ; true ou false, un booléen.");
      }
      for (const res of [a, b]) {
        if (res.doublons?.length) p.push(`${SCHEMA_NOM(res.version)} : la clé ${reprNoeud(res.doublons[0])} est répétée ; la dernière valeur l’emporte.`);
        const cles = res.noeud.t === "dict" ? res.noeud.v.map(([k]) => k).filter(k => k.t !== "str") : [];
        if (cles.length) p.push(`Lecture ${res.version} : la clé ${reprNoeud(cles[0])} n’est pas une chaîne (${NOM_TYPE[cles[0].t]}) ; JSON la réécrit en chaîne${cles[0].t === "date" ? "… sauf une date, que json.dumps refuse comme clé" : ""}.`);
      }
      p.push(...phrasesJson(r.versions));
    }
    return p;
  }
  const expliquer = r => r.entree.mode === "document" ? expliquerDocument(r) : expliquerScalaire(r);

  // Les exemples de la liste déroulante et les documents du mode « document ».
  const EXEMPLES = [
    ["Booléens", ["true", "NO", "yes", "on", "y", "\"NO\""]],
    ["Nombres", ["42", "0644", "0o644", "0x1F", "22:22", "1:30", "1e3", "1e+3", "1.10", ".inf", "007", "08"]],
    ["Nul, chaînes, dates", ["~", "null", "", "web01", "1.2.3", "2026-11-25", "2026-11-25T10:00:00+01:00"]],
    ["Guillemets et étiquettes", ["'0644'", "\"22:22\"", "'~'", "\"2026-11-25\"", "!!str NO", "!!int 0644", "!!bool yes"]],
  ];
  const DOCUMENTS = [
    ["norvege.yaml (cours)", "---\npays: [FR, NO, SE]\nactif: yes"],
    ["typage.yaml (cours, abrégé)", "---\nmode: 0644\nmode_12: 0o644\nduree: 22:22\ndate: 2024-01-15\ntitre: 1984"],
    ["pieges.yaml (TP)", "---\ntitre: 1984\ntraductions: [fr, de, no]\ndisponible: yes\ncote: 0123\nduree_lecture: 7:30\npublication: 1949-06-08"],
    ["pieges-corrige.yaml (TP)", "---\n# guillemets pour les chaînes, true pour le booléen\ntitre: \"1984\"\ntraductions: [fr, de, \"no\"]\ndisponible: true\ncote: \"0123\"\nduree_lecture: \"7:30\"\npublication: \"1949-06-08\""],
    ["clés qui changent de type", "---\nyes: oui\n80: http\n2026-11-25: jour"],
  ];
  const depart = () => ({ mode: "scalaire", texte: "NO", document: DOCUMENTS[0][1] });
  const entreeDe = e => ({ mode: e.mode, texte: e.mode === "document" ? e.document : e.texte });

  if (typeof module !== "undefined") module.exports = { simuler, simulerScalaire, simulerDocument, expliquer, depart, entreeDe, jsonDumps, pyFloat, pyStr, SCHEMAS, EXEMPLES, DOCUMENTS, reprNoeud, arbre };
  if (typeof document === "undefined") return;

  // ---------- Interface ----------
  const { el, bouton, recettes } = Artefact;   // création d'éléments et moteur de recettes : commun/artefact.js
  const racine = document.getElementById("artefact");
  const PAUSE = 1300;        // en ms : entre deux étapes d'une recette qui s'enchaîne sans pause
  const PHASE = 450;         // en ms : chaque moment d'une lecture (types, JSON, explication) se voit passer

  let etat = depart();
  let phase = 3;             // 0 : rien d'affiché ; 1 : types et valeurs ; 2 : JSON ; 3 : explication
  let tour = 0;              // numéro de la lecture : une lecture annulée s'y reconnaît
  const absent = (texte = "…") => el("p", { class: "vide" }, texte);
  const resultat = () => simuler(entreeDe(etat));

  // Un nœud : son type en toutes lettres (le texte porte l'information), sa valeur comme Python l'écrit.
  const badge = (n, repr) => el("span", { class: `type type-${n.t}` }, NOM_TYPE[n.t]);
  const valeurDe = (n, repr) => el("code", { class: "valeur" }, repr ?? reprNoeud(n));

  function carteScalaire(res, v) {
    const s = SCHEMAS[v], r = res.versions[v];
    const corps = !r ? absent("—")
      : !r.ok ? el("div", { class: "lecture" },
        el("p", { class: "erreur" }, `${r.erreur.classe} : ${r.erreur.message}`),
        el("p", { class: "mention" }, "La conversion échoue : aucune valeur."))
      : el("div", { class: "lecture" },
        el("p", { class: "ligne" }, el("span", { class: "champ" }, "Type"), badge(r.noeud)),
        el("p", { class: "ligne" }, el("span", { class: "champ" }, "Valeur"), valeurDe(r.noeud, r.repr)),
        el("p", { class: "ligne regle" }, el("span", { class: "champ" }, "Règle"), el("span", {}, phraseRegle(r))));
    return corps;
  }
  const blocJson = (r, ph) => ph < 2 ? absent() : !r ? absent("—")
    : !r.ok ? el("p", { class: "vide" }, "Rien à convertir.")
      : r.json.erreur ? el("p", { class: "erreur" }, `${r.json.erreur.classe} : ${r.json.erreur.message}`)
        : el("div", { class: "json" }, el("code", {}, r.json.texte));

  function ligneDocument(l, v) {
    const cle = l.noeudCle, val = l.valeur;
    const noeuds = val.genre === "scalaire" ? [val] : val.items;
    return el("tr", {},
      el("th", { scope: "row" }, el("code", {}, reprNoeud(cle)), ...(cle.t !== "str" ? [el("small", {}, NOM_TYPE[cle.t])] : [])),
      el("td", {}, val.genre === "liste" ? el("span", { class: "liste" }, "liste ", ...noeuds.flatMap((x, i) => [i ? ", " : "", el("span", { class: `item type-${x.noeud.t}`, title: NOM_TYPE[x.noeud.t] }, el("code", {}, reprNoeud(x.noeud)), el("small", {}, NOM_TYPE[x.noeud.t]))]))
        : el("span", { class: `item type-${val.noeud.t}` }, el("code", {}, reprNoeud(val.noeud)), el("small", {}, NOM_TYPE[val.noeud.t]))));
  }
  function carteDocument(res, v) {
    const r = res.versions[v];
    if (!r) return absent("—");
    if (!r.ok) return el("div", { class: "lecture" }, el("p", { class: "erreur" }, `${r.erreur.classe} : ${r.erreur.message}`), el("p", { class: "mention" }, "Le document entier est refusé."));
    return r.lignes.length ? el("table", { class: "paires" }, el("tbody", {}, ...r.lignes.map(l => ligneDocument(l, v)))) : absent("Document vide : None.");
  }

  function dessinerResultats() {
    const res = resultat(), ph = phase;
    const cadre = (cible, ...contenu) => racine.querySelector(cible).replaceChildren(...contenu);
    const doc = etat.mode === "document";
    const bloque = res.limites.length || res.erreurSyntaxe;
    for (const v of VERSIONS) {
      const s = SCHEMAS[v];
      cadre(`.zone-v${v.replace(".", "")}`,
        el("h2", {}, el("span", {}, s.nom), el("small", {}, s.analyseur)),
        el("div", { class: "corps" },
          el("div", { class: "lu" },
            ph < 1 ? absent() : bloque ? el("p", { class: res.erreurSyntaxe ? "erreur" : "limite" },
              res.erreurSyntaxe ? `${res.erreurSyntaxe.classe} : ${res.erreurSyntaxe.message}` : "Limitation du simulateur : voir plus bas.")
              : doc ? carteDocument(res, v) : carteScalaire(res, v)),
          el("div", { class: "en-json" },
            el("p", { class: "champ titre-json" }, "JSON (json.dumps)"),
            ph < 2 || bloque ? absent() : blocJson(res.versions[v], ph))));
    }
    const phrases = ph < 3 ? ["…"] : expliquer(res);
    cadre(".zone-explication",
      el("h2", {}, "Ce que dit le résultat"),
      el("div", { class: "explication-texte", role: "status", "aria-live": "polite" },
        ...phrases.map(f => el("p", { class: f.startsWith("Limitation") ? "limite" : /refusent|échoue/.test(f) && !f.includes("même façon") ? "erreur" : "" }, f))));
    // La ligne telle qu'elle serait écrite dans le fichier.
    const apercu = racine.querySelector(".apercu");
    if (apercu) apercu.textContent = doc ? "" : `clé: ${etat.texte}`;
  }

  // ---------- Contrôles : créés une fois, relus par `appliquer` ----------
  const modifie = () => { phase = 3; appliquer(); dessinerResultats(); aLaMain(); };
  const aLaMain = () => moteur.libre(expliquer(resultat()));
  function batir() {
    const champTexte = el("input", { type: "text", spellcheck: "false", autocomplete: "off", "aria-label": "Le scalaire, tel qu’il est écrit après « clé: »", "data-cle": "texte",
      placeholder: "ex. NO ou \"NO\"", oninput: ev => { etat.texte = ev.target.value; modifie(); } });
    const exemples = el("select", { "aria-label": "Un exemple de scalaire", "data-exemples": "",
      onchange: ev => { if (ev.target.value === "") return; etat.texte = ev.target.value === "\u0000" ? "" : ev.target.value; modifie(); ev.target.value = ""; } },
      el("option", { value: "" }, "Un exemple…"),
      ...EXEMPLES.map(([groupe, liste]) => el("optgroup", { label: groupe }, ...liste.map(t => el("option", { value: t === "" ? "\u0000" : t }, t === "" ? "(vide)" : t)))));
    const documents = el("select", { "aria-label": "Un document d’exemple", "data-docs": "",
      onchange: ev => { if (ev.target.value === "") return; etat.document = DOCUMENTS[+ev.target.value][1]; modifie(); ev.target.value = ""; } },
      el("option", { value: "" }, "Un document…"), ...DOCUMENTS.map(([nom], i) => el("option", { value: String(i) }, nom)));
    const zoneDocument = el("textarea", { rows: "6", spellcheck: "false", "aria-label": "Le document YAML", "data-cle": "document",
      oninput: ev => { etat.document = ev.target.value; modifie(); } });
    const mode = (valeur, texte) => el("button", { type: "button", class: "mode", "data-mode": valeur, "aria-pressed": "false",
      onclick: () => { if (moteur.fige() || etat.mode === valeur) return; etat.mode = valeur; modifie(); } }, texte);
    racine.replaceChildren(
      el("section", { class: "zone-entree cadre" },
        el("div", { class: "saisie" },
          el("div", { class: "entree entree-scalaire" },
            el("code", { class: "cle" }, "clé:"), champTexte,
            el("p", { class: "mention" }, "Tel qu’il est écrit dans le fichier, guillemets compris : ", el("code", { class: "apercu" }))),
          el("div", { class: "entree entree-document" }, zoneDocument)),
        el("div", { class: "commandes" },
          el("h2", {}, "Ce que vous écrivez"),
          el("div", { class: "modes", role: "group", "aria-label": "Mode" }, mode("scalaire", "Un scalaire"), mode("document", "Un document")),
          exemples, documents,
          bouton("Remettre à zéro", () => { moteur.fermer(); etat = depart(); phase = 3; appliquer(); dessinerResultats(); }, { class: "zero" }))),
      el("section", { class: "zone-v11 cadre" }),
      el("section", { class: "zone-v12 cadre" }),
      el("section", { class: "zone-explication cadre" }));
  }
  // Remet les contrôles d'accord avec l'état, et bloque la saisie pendant une recette.
  function appliquer() {
    for (const c of racine.querySelectorAll("[data-cle]")) {
      const v = etat[c.dataset.cle];
      if (c.value !== v) c.value = v;
      c.disabled = moteur.fige();
    }
    const zone = racine.querySelector("textarea");
    zone.rows = Math.min(9, Math.max(3, etat.document.split("\n").length));
    for (const c of racine.querySelectorAll("[data-exemples], [data-docs]")) c.disabled = moteur.fige();
    for (const b of racine.querySelectorAll(".mode")) { b.setAttribute("aria-pressed", String(b.dataset.mode === etat.mode)); b.disabled = moteur.fige(); }
    racine.dataset.mode = etat.mode;
    for (const b of racine.querySelectorAll(".zero")) b.disabled = false;
  }

  // ---------- Recettes : les manipulations des expériences, jouées pas à pas ----------
  const decrire = (avant, apres) => avant.mode !== apres.mode ? `Mode « ${apres.mode === "document" ? "document" : "scalaire"} ».` : null;
  // Une action de recette règle l'entrée, puis lit : elle rend l'explication de ce qui vient de se passer.
  const regler = changements => async () => {
    const moi = ++tour;
    const decrits = [];
    const avant = { ...etat };
    if (changements.mode && changements.mode !== etat.mode) decrits.push(decrire(avant, { ...avant, mode: changements.mode }));
    if (changements.texte !== undefined && changements.texte !== etat.texte)
      decrits.push(`Le scalaire écrit : ${changements.texte === "" ? "rien" : changements.texte}.`);
    if (changements.document !== undefined && changements.document !== etat.document) decrits.push("Le document est remplacé.");
    phase = 0; Object.assign(etat, changements); appliquer(); dessinerResultats();
    for (const c of racine.querySelectorAll(etat.mode === "document" ? "[data-cle=document]" : "[data-cle=texte]")) c.classList.add("signale");
    for (const p of [1, 2, 3]) {
      await moteur.attendre(PHASE);
      if (moi !== tour) return [];
      phase = p; dessinerResultats();
    }
    for (const c of racine.querySelectorAll(".signale")) c.classList.remove("signale");
    return [...(decrits.length ? [decrits.join(" ")] : []), ...expliquer(resultat())];
  };
  const S = texte => regler({ mode: "scalaire", texte });
  const PIEGES_CORRIGE = "---\npays: [FR, \"NO\", SE]\nactif: true";
  const RECETTES = {
    norvege: [
      ["Écrire NO, sans guillemets.", S("NO")],
      ["Entourer NO de guillemets doubles.", S('"NO"')],
      ["Écrire yes, sans guillemets.", S("yes")],
    ],
    octal: [
      ["Écrire 0644.", S("0644")],
      ["Écrire 0o644.", S("0o644")],
      ["Entourer 0644 de guillemets simples.", S("'0644'")],
    ],
    "base-60": [
      ["Écrire 22:22.", S("22:22")],
      ["Écrire 1:30.", S("1:30")],
      ["Entourer 22:22 de guillemets doubles.", S('"22:22"')],
    ],
    "date-json": [
      ["Écrire 2026-11-25.", S("2026-11-25")],
      ["Entourer 2026-11-25 de guillemets doubles.", S('"2026-11-25"')],
      ["Écrire 2026-13-45.", S("2026-13-45")],
    ],
    "document-json": [
      ["Passer en mode document avec norvege.yaml.", regler({ mode: "document", document: DOCUMENTS[0][1] })],
      ["Écrire \"NO\" entre guillemets et true à la place de yes.", regler({ mode: "document", document: PIEGES_CORRIGE })],
      ["Ajouter la ligne mode: 0644.", regler({ mode: "document", document: PIEGES_CORRIGE + "\nmode: 0644" })],
    ],
  };
  // L'état de la simulation : mémorisé après chaque étape d'une recette, pour pouvoir y revenir.
  const capturer = () => structuredClone({ etat });
  function retablir(sauvegarde) {
    tour++;   // une lecture en cours d'exécution est abandonnée
    etat = structuredClone(sauvegarde.etat); phase = 3;
    for (const c of racine.querySelectorAll(".signale")) c.classList.remove("signale");
    appliquer(); dessinerResultats();
  }
  const moteur = recettes({ recettes: RECETTES, depart: ["Départ : le scalaire NO, sans guillemets."],
    titreLibre: "Votre texte", pause: () => PAUSE,
    remettre: () => { etat = depart(); phase = 3; dessinerResultats(); }, capturer, retablir, afficher: appliquer });

  batir();
  appliquer();
  dessinerResultats();
})();
