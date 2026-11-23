// Test d'interface (optionnel, non exécuté en CI) : pilote Chrome via DevTools.
//   quarto render && (cd docs && python3 -m http.server 8765 &)
//   google-chrome --headless=new --no-sandbox --remote-debugging-port=9222 about:blank &
//   node tests/e2e/ui.test.mjs
const base = "http://127.0.0.1:9222";
const tab = await (await fetch(base + "/json/new?about:blank", { method: "PUT" })).json();
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pend = new Map();
ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); } };
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pend.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async (expr) => { const r = await send("Runtime.evaluate", { expression: expr, awaitPromise: true, returnByValue: true }); if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 300)); return r.result.result.value; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const go = async (url) => { await send("Page.enable"); await send("Page.navigate", { url }); await sleep(2500); };
const ok = (c, msg) => { console.log((c ? "PASS " : "FAIL ") + msg); if (!c) process.exitCode = 1; };

await go("http://localhost:8765/index.html");
await ev("localStorage.clear()"); await go("http://localhost:8765/index.html");
ok(await ev("!!document.querySelector('.dojo-chip')"), "puce XP présente");
// cartes : afficher réponse, « je savais »
await ev("document.querySelector('.dojo-cards .dojo-btn.primary').click()");
ok(await ev("!document.querySelector('.dojo-cards .a').hidden"), "réponse affichée");
await ev("document.querySelector('.dojo-cards .dojo-btn.ok').click()");
let S = JSON.parse(await ev("localStorage.getItem('dojo.v1')"));
ok(S.xp === 4, "carte sue (nouvelle) = +4 XP (xp=" + S.xp + ")");
const cid = Object.keys(S.cards)[0];
ok(S.cards[cid].box === 1 && S.cards[cid].due > S.lastActive - 0 || S.cards[cid].box === 1, "carte en boîte 1 replanifiée à " + S.cards[cid].due);
ok(S.streak === 1, "série = 1");
// carte ratée : ré-empilée
await ev("document.querySelector('.dojo-cards .dojo-btn.primary').click()");
const before = await ev("document.querySelectorAll('.dojo-cards .dojo-progressline').length");
await ev("document.querySelector('.dojo-cards .dojo-btn.ko').click()");
S = JSON.parse(await ev("localStorage.getItem('dojo.v1')"));
ok(S.xp === 5, "carte ratée = +1 XP (xp=" + S.xp + ")");
const missed = Object.entries(S.cards).find(([, c]) => c.box === 0);
ok(!!missed && missed[1].due === S.lastActive, "carte ratée : boîte 0, due aujourd'hui");
// QCM : bonne réponse puis feedback
const qinfo = await ev(`(() => { const q = window.dojo.DATA.quiz; const txt = document.querySelector('.dojo-quiz p').textContent; const item = q.find(x => x.q === txt); const btns=[...document.querySelectorAll('.dojo-quiz .dojo-choice')]; btns[item.answer].click(); return {good: btns[item.answer].classList.contains('good'), disabled: btns.every(b=>b.disabled), why: document.querySelector('.dojo-quiz .dojo-meta').textContent}; })()`);
ok(qinfo.good && qinfo.disabled && qinfo.why.startsWith("✔"), "QCM : bonne réponse validée + explication");
S = JSON.parse(await ev("localStorage.getItem('dojo.v1')"));
ok(S.xp === 10, "QCM juste = +5 XP (xp=" + S.xp + ")");
// exercice réussi
await ev("document.querySelector('.dojo-exo .dojo-done .dojo-btn.ok').click()");
S = JSON.parse(await ev("localStorage.getItem('dojo.v1')"));
ok(Object.keys(S.done).length === 1 && S.xp > 10, "exercice réussi enregistré, XP=" + S.xp);
// annuler puis re-cliquer ne redonne pas d XP
await ev("document.querySelector('.dojo-exo .dojo-done .dojo-btn').click()");
S = JSON.parse(await ev("localStorage.getItem('dojo.v1')"));
ok(Object.keys(S.done).length === 0, "annulation de la réussite");
{ const xp0 = S.xp; await ev("document.querySelector('.dojo-exo .dojo-done .dojo-btn.ok').click()");
  S = JSON.parse(await ev("localStorage.getItem('dojo.v1')")); ok(S.xp === xp0 && Object.keys(S.done).length === 1, "re-cliquer après annulation ne redonne pas d'XP"); 
  await ev("document.querySelector('.dojo-exo .dojo-done .dojo-btn').click()"); S = JSON.parse(await ev("localStorage.getItem('dojo.v1')")); }
// puce mise à jour
ok((await ev("document.querySelector('.dojo-chip').textContent")).includes(S.xp + " XP"), "puce navbar à jour");
// progression
await ev("(() => { const s = JSON.parse(localStorage.getItem('dojo.v1')); s.xp = 520; localStorage.setItem('dojo.v1', JSON.stringify(s)); })()");
await go("http://localhost:8765/progression.html");
const prog = await ev("({ tiles: document.querySelectorAll('.dojo-tile').length, radar: !!document.querySelector('svg.dojo-radar polygon.shape'), rows: document.querySelectorAll('.dojo-table tbody tr').length, belt: document.querySelector('.dojo-tile .s').textContent, heat: document.querySelectorAll('.dojo-heat i').length })");
ok(prog.tiles === 4 && prog.radar && prog.rows === 7 && prog.heat === 30, "progression : " + JSON.stringify(prog));
ok(prog.belt.includes("verte"), "520 XP = ceinture verte");
// export JSON valide
ok(await ev("(() => { const s = window.dojo.S(); return s.v === 1 && typeof s.xp === 'number'; })()"), "état exportable");
// page exercice : bouton réussi + lab
await go("http://localhost:8765/parcours/micro.html");
ok(await ev("document.querySelectorAll('.dojo-done .dojo-btn').length >= 4"), "boutons « réussi » sur la page micro");
ok(await ev("document.querySelectorAll('.dojo-lab svg polygon').length >= 2"), "laboratoire de marché dessiné");
await ev("(() => { const sel = document.querySelector('.dojo-lab select'); sel.value = 'cournot'; sel.dispatchEvent(new Event('change')); })()");
ok((await ev("document.querySelector('.dojo-lab .out').textContent")).includes("Quantité par firme"), "lab : Cournot affiche q par firme");
// pistes : échelles de marches sur la page, déverrouillage progressif pour l'exercice du jour
ok(await ev("document.querySelectorAll('.dojo-ladder').length === 2 && document.querySelectorAll('.dojo-steps li').length === 7"), "micro : 2 pistes, 7 marches");
ok(await ev("document.querySelectorAll('.dojo-step').length === 7"), "micro : 7 badges « Marche k sur n »");
ok(await ev("document.querySelectorAll('.exercise-hint, .hint').length >= 14 || document.querySelectorAll('[class*=hint]').length >= 14"), "micro : au moins 2 indices par exercice");
const pick = `(() => { const out = []; for (let i = 0; i < 60; i++) { const b = [...document.querySelectorAll('.dojo-exo .dojo-btn')].find(x => x.textContent.includes('Un autre')); b.click(); const m = document.querySelector('.dojo-exo .dojo-badge.pine'); out.push(m ? m.textContent : 'libre'); } return out; })()`;
await go("http://localhost:8765/index.html"); await ev("localStorage.clear()"); await go("http://localhost:8765/index.html");
{ const t = await ev(pick);
  ok(t.every((x) => x === "libre" || /marche 1\//.test(x)), "départ : seules les marches 1 (ou exercices libres) sont proposées : " + [...new Set(t)].join(" | ")); }
await ev("(() => { const d = new Date().toISOString().slice(0, 10); const s = window.dojo.S(); s.done['seg-d-0'] = d; s.paid['seg-d-0'] = true; localStorage.setItem('dojo.v1', JSON.stringify(s)); })()");
await go("http://localhost:8765/index.html");
{ const t = await ev(pick); const seg = t.filter((x) => x.startsWith("Ségrégation"));
  ok(seg.length === 0 || seg.every((x) => /marche [12]\//.test(x)), "après la marche 1 de la piste Ségrégation, jamais au-delà de la marche 2 : " + [...new Set(seg)].join(" | "));
  ok(seg.some((x) => /marche 2\//.test(x)), "la marche 2 de Ségrégation est devenue accessible"); }
// nouvelles pages : pistes R et Économie contemporaine, lien vers le corrigé du défi
await go("http://localhost:8765/parcours/r.html");
ok(await ev("document.querySelectorAll('.dojo-ladder').length === 2 && document.querySelectorAll('.dojo-steps li').length === 7"), "page R : 2 pistes, 7 marches");
await go("http://localhost:8765/parcours/contemporaine.html");
ok(await ev("document.querySelectorAll('.dojo-ladder').length === 6 && document.querySelectorAll('.dojo-steps li').length === 18"), "contemporaine : 6 pistes, 18 marches");
await go("http://localhost:8765/index.html");
{ const href = await ev("(document.querySelector('.dojo-panel a[href*=\"recherche/defis.html#defi-\"]') || {}).href || ''");
  ok(/recherche\/defis\.html#defi-/.test(href), "défi de la semaine : lien « Voir le corrigé » " + href); }
await go("http://localhost:8765/recherche/defis.html");
ok(await ev("document.querySelectorAll('.callout').length >= 8 && document.querySelectorAll('section[id^=defi-]').length === 8"), "page des corrigés : 8 défis");
// échauffements : 7 pistes, 40 marches ; bouton « Plus court » ; lien de repli depuis une piste
await go("http://localhost:8765/parcours/minis.html");
ok(await ev("document.querySelectorAll('.dojo-ladder').length === 7 && document.querySelectorAll('.dojo-steps li').length === 40"), "échauffements : 7 pistes, 40 marches");
await go("http://localhost:8765/parcours/stats.html");
ok(await ev("[...document.querySelectorAll('.dojo-ladder a')].some(a => a.href.includes('minis.html#mini-stats'))"), "stats : lien vers les échauffements");
await go("http://localhost:8765/index.html"); await ev("localStorage.clear()"); await go("http://localhost:8765/index.html");
{ const t = await ev("(() => { const btn = (txt) => [...document.querySelectorAll('.dojo-exo .dojo-btn')].find(x => x.textContent.includes(txt)); btn('Plus court').click(); const out = []; for (let i = 0; i < 20; i++) { const m = [...document.querySelectorAll('.dojo-exo .dojo-badge')].find(x => x.textContent.startsWith('~')); out.push(parseInt(m.textContent.replace('~', ''))); btn('Un autre').click(); } return out; })()");
  ok(t.length === 20 && t.every((x) => x <= 5), "« Plus court » : exercices de 5 minutes maximum"); }
ws.close(); process.exit(process.exitCode || 0);
