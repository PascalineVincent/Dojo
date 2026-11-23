// Le Dojo : moteur front (module ES). Aucune dépendance. État dans localStorage.
//  - XP, ceintures, série (streak)
//  - flashcards en répétition espacée (boîtes de Leitner)
//  - QCM, exercice du jour, défi de la semaine, veille, progression, laboratoire
// Points de montage : .dojo-cards .dojo-quiz .dojo-exo .dojo-defi .dojo-veille
//                     .dojo-progress .dojo-done .dojo-lab .dojo-plan

const ROOT = new URL('../', import.meta.url);           // racine du site
const KEY = 'dojo.v1';
const INTERVALS = [0, 1, 2, 4, 8, 16];                  // jours avant révision, par boîte 0..5
const BELTS = [
  { at: 0,    emoji: '⚪', name: 'Ceinture blanche · Novice' },
  { at: 100,  emoji: '🟡', name: 'Ceinture jaune · Apprenti' },
  { at: 250,  emoji: '🟠', name: 'Ceinture orange · Praticien' },
  { at: 500,  emoji: '🟢', name: 'Ceinture verte · Confirmé' },
  { at: 900,  emoji: '🔵', name: 'Ceinture bleue · Chercheur' },
  { at: 1500, emoji: '🟤', name: 'Ceinture marron · Expert' },
  { at: 2500, emoji: '⚫', name: 'Ceinture noire · Docteur' },
  { at: 4000, emoji: '🎓', name: 'Maître · Directeur de thèse' },
];
const COURSE_LABEL = {
  micro: 'Micro', stats: 'Statistiques', econometrie: 'Économétrie', histoire: 'Histoire éco.',
  contemporaine: 'Éco. contemporaine', recherche: 'Recherche', r: 'R',
};

// ------------------------------------------------------------------ utilitaires
const ymd = (d = new Date()) => d.toLocaleDateString('sv-SE');           // AAAA-MM-JJ, date locale
const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (s) => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>');       // texte brut + `code`
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
function h(tag, attrs = {}, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') el.className = v;
    else if (k === 'html') el.innerHTML = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (v !== false && v != null) el.setAttribute(k, v);
  }
  for (const c of kids.flat()) el.append(c instanceof Node ? c : document.createTextNode(c ?? ''));
  return el;
}
const hashStr = (s) => { let x = 2166136261; for (const c of s) { x ^= c.charCodeAt(0); x = Math.imul(x, 16777619); } return x >>> 0; };
const prng = (seed) => () => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
function shuffle(arr, rnd = Math.random) { const a = [...arr]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }

// ------------------------------------------------------------------ état
const fresh = () => ({ v: 1, xp: 0, days: {}, cards: {}, quiz: {}, done: {}, paid: {}, lastActive: null, streak: 0, bestStreak: 0 });
let S = fresh();
try { S = Object.assign(fresh(), JSON.parse(localStorage.getItem(KEY) || '{}')); } catch { /* stockage indisponible */ }
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch { /* ignoré */ } };

function touch() {
  const t = ymd();
  if (S.lastActive !== t) {
    S.streak = S.lastActive === ymd(addDays(new Date(), -1)) ? S.streak + 1 : 1;
    S.lastActive = t;
    S.bestStreak = Math.max(S.bestStreak, S.streak);
  }
}
function addXP(n) {
  if (!n) return;
  touch();
  S.xp += n;
  S.days[ymd()] = (S.days[ymd()] || 0) + n;
  save(); renderChip();
}
const beltIndex = (xp = S.xp) => BELTS.reduce((acc, b, i) => (xp >= b.at ? i : acc), 0);
function liveStreak() {                                   // la série est « vivante » si active hier ou aujourd'hui
  const t = ymd(), y = ymd(addDays(new Date(), -1));
  return S.lastActive === t || S.lastActive === y ? S.streak : 0;
}

// ------------------------------------------------------------------ données
let DATA = { cards: [], quiz: [], exercises: [], defi: null, veille: [], courses: [] };
try { DATA = await (await fetch(new URL('assets/data.json', ROOT))).json(); } catch (e) { console.warn('data.json indisponible', e); }

// maîtrise par cours : moyenne des composantes disponibles (cartes en boîte >= 3, exercices faits, QCM justes)
function mastery() {
  const out = {};
  for (const c of DATA.courses || []) {
    const parts = [];
    const cards = DATA.cards.filter((x) => x.course === c);
    if (cards.length) parts.push(cards.filter((x) => (S.cards[x.id]?.box ?? 0) >= 3).length / cards.length);
    const ex = DATA.exercises.filter((x) => x.course === c);
    if (ex.length) parts.push(ex.filter((x) => S.done[x.id]).length / ex.length);
    const qz = DATA.quiz.filter((x) => x.course === c);
    if (qz.length) parts.push(qz.filter((x) => (S.quiz[x.id]?.last) === 1).length / qz.length);
    out[c] = parts.length ? parts.reduce((a, b) => a + b, 0) / parts.length : 0;
  }
  return out;
}

// ------------------------------------------------------------------ puce dans la navbar
function renderChip() {
  const host = document.querySelector('#navbarCollapse') || document.querySelector('.navbar-container');
  if (!host) return;
  let chip = document.querySelector('.dojo-chip');
  if (!chip) { chip = h('a', { class: 'dojo-chip', href: new URL('progression.html', ROOT).href }); host.append(chip); }
  const i = beltIndex(), b = BELTS[i], nxt = BELTS[i + 1];
  const pct = nxt ? Math.round(100 * (S.xp - b.at) / (nxt.at - b.at)) : 100;
  chip.innerHTML = `<span title="${esc(b.name)}">${b.emoji}</span><span>${S.xp} XP</span>`
    + `<span class="bar" title="${pct}% vers la prochaine ceinture"><i style="width:${pct}%"></i></span>`
    + `<span title="Série en cours">🔥 ${liveStreak()}</span>`;
}

// ------------------------------------------------------------------ flashcards (Leitner)
function pickCards(course, n) {
  const t = ymd(), m = mastery();
  const pool = DATA.cards.filter((c) => !course || c.course === course);
  const due = pool.filter((c) => S.cards[c.id] && S.cards[c.id].due <= t)
    .sort((a, b) => S.cards[a.id].due.localeCompare(S.cards[b.id].due) || S.cards[a.id].box - S.cards[b.id].box);
  const rnd = prng(hashStr(t + (course || '')));
  const news = shuffle(pool.filter((c) => !S.cards[c.id]), rnd)
    .sort((a, b) => (m[a.course] ?? 0) - (m[b.course] ?? 0) + (rnd() - 0.5) * 0.3);   // priorité aux cours faibles
  return [...due, ...news].slice(0, n);
}
function reviewCard(card, ok) {
  const st = S.cards[card.id] || { box: 0, seen: 0, ok: 0, ko: 0, due: ymd() };
  st.seen++; ok ? st.ok++ : st.ko++;
  st.box = ok ? Math.min(5, st.box + 1) : 0;
  st.due = ymd(addDays(new Date(), INTERVALS[st.box] || 0));
  S.cards[card.id] = st;
  addXP(ok ? (st.box <= 1 ? 4 : 2) : 1);
}
function mountCards(el) {
  const n = +el.dataset.n || 5, course = el.dataset.course || '';
  const run = () => {
    const queue = pickCards(course, n); const total = queue.length; let idx = 0, good = 0, retried = new Set();
    el.innerHTML = '';
    if (!total) { el.append(h('div', { class: 'dojo-panel' }, 'Aucune carte disponible pour le moment.')); return; }
    const bar = h('div', { class: 'dojo-progressline' }, h('i'));
    const stage = h('div');
    el.append(bar, stage);
    const step = () => {
      bar.firstChild.style.width = `${100 * idx / total}%`;
      if (idx >= queue.length) {
        stage.innerHTML = '';
        stage.append(h('div', { class: 'dojo-panel' },
          h('h4', {}, 'Session terminée'),
          h('p', {}, `${good} carte(s) sue(s) sur ${total}. Les cartes ratées reviendront à la prochaine session ; les autres sont replanifiées (${INTERVALS.slice(1).join(' / ')} jours selon la boîte).`),
          h('button', { class: 'dojo-btn primary', onclick: run }, 'Une autre série')));
        return;
      }
      const c = queue[idx], box = S.cards[c.id]?.box;
      const answer = h('div', { class: 'a', hidden: true, html: fmt(c.a) });
      const reveal = h('button', { class: 'dojo-btn primary' }, 'Afficher la réponse');
      const rate = h('div', { hidden: true },
        h('button', { class: 'dojo-btn ok', onclick: () => { reviewCard(c, true); good++; idx++; step(); } }, '✔ Je savais'),
        h('button', { class: 'dojo-btn ko', onclick: () => { reviewCard(c, false); if (!retried.has(c.id)) { retried.add(c.id); queue.push(c); } idx++; step(); } }, '✘ À revoir'));
      reveal.onclick = () => { answer.hidden = false; rate.hidden = false; reveal.hidden = true; };
      stage.innerHTML = '';
      stage.append(h('div', { class: 'dojo-card' },
        h('div', {}, h('span', { class: 'dojo-badge' }, COURSE_LABEL[c.course] || c.course),
          h('span', { class: 'dojo-badge' }, 'niveau ' + c.level),
          h('span', { class: 'dojo-badge' }, box === undefined ? 'nouvelle' : 'boîte ' + box)),
        h('div', { class: 'q', html: fmt(c.q) }), answer, reveal, rate));
    };
    step();
  };
  run();
}

// ------------------------------------------------------------------ QCM
function mountQuiz(el) {
  const n = +el.dataset.n || 3, course = el.dataset.course || '';
  const run = () => {
    const pool = DATA.quiz.filter((q) => !course || q.course === course);
    const rnd = prng(hashStr(ymd() + course + Math.random()));
    const items = shuffle(pool, rnd).sort((a, b) => (S.quiz[a.id]?.last === 1) - (S.quiz[b.id]?.last === 1)).slice(0, n);
    let i = 0, score = 0;
    el.innerHTML = '';
    if (!items.length) { el.append(h('div', { class: 'dojo-panel' }, 'Aucun QCM disponible.')); return; }
    const stage = h('div'); el.append(stage);
    const step = () => {
      stage.innerHTML = '';
      if (i >= items.length) {
        stage.append(h('div', { class: 'dojo-panel' }, h('h4', {}, `Score : ${score} / ${items.length}`),
          h('button', { class: 'dojo-btn primary', onclick: run }, 'Nouveau tirage')));
        return;
      }
      const q = items[i];
      const why = h('div', { class: 'dojo-meta', hidden: true });
      const next = h('button', { class: 'dojo-btn primary', hidden: true, onclick: () => { i++; step(); } }, i + 1 < items.length ? 'Suivant' : 'Terminer');
      const btns = q.choices.map((c, k) => h('button', { class: 'dojo-choice', onclick: () => {
        const ok = k === q.answer;
        btns.forEach((b, j) => { b.disabled = true; if (j === q.answer) b.classList.add('good'); else if (j === k) b.classList.add('bad'); });
        const st = S.quiz[q.id] || { ok: 0, ko: 0 }; ok ? st.ok++ : st.ko++; st.last = ok ? 1 : 0; S.quiz[q.id] = st;
        if (ok) score++;
        addXP(ok ? 5 : 1);
        why.hidden = false; why.innerHTML = (ok ? '✔ ' : '✘ ') + fmt(q.why); next.hidden = false;
      } }, c));
      stage.append(h('div', { class: 'dojo-panel' },
        h('div', {}, h('span', { class: 'dojo-badge' }, COURSE_LABEL[q.course] || q.course), h('span', { class: 'dojo-badge' }, `question ${i + 1}/${items.length}`)),
        h('p', { html: fmt(q.q), style: 'font-weight:600;margin:.6rem 0' }), ...btns, why, next));
    };
    step();
  };
  run();
}

// ------------------------------------------------------------------ boutons « exercice réussi »
function mountDone(el) {
  const id = el.dataset.id;
  const meta = DATA.exercises.find((x) => x.id === id) || {};
  const xp = +el.dataset.xp || meta.xp || 20;
  const draw = () => {
    el.innerHTML = '';
    if (S.done[id]) {
      el.append(h('span', { class: 'dojo-badge pine' }, `✔ réussi le ${S.done[id]}`),
        h('button', { class: 'dojo-btn', onclick: () => { delete S.done[id]; save(); draw(); } }, 'Annuler'));
    } else {
      el.append(h('button', { class: 'dojo-btn ok', onclick: () => { S.done[id] = ymd(); if (!S.paid[id]) { S.paid[id] = true; addXP(xp); } else save(); draw(); } }, `✔ Exercice réussi (+${xp} XP)`));
    }
  };
  draw();
}

// ------------------------------------------------------------------ exercice du jour
const dayRank = () => { const d = new Date().getDay(); return d === 0 || d === 6; };     // week-end ?
const TRACK_LABEL = { 'micro-cpp': 'Concurrence parfaite', 'micro-pouvoir': 'Pouvoir de marché', 'stats-est': 'Estimation et simulation', 'stats-desc': 'Statistiques descriptives', 'stats-tests': 'Comparaisons et tests',
  eco: 'Économétrie', 'con-dette': 'Dette publique', 'con-prix': 'Inflation et prix', 'con-croiss': 'Croissance', 'con-travail': 'Marché du travail', 'con-monnaie': 'Politique monétaire', 'con-commerce': 'Commerce extérieur', 'r-base': 'R : bases', 'mini-r': 'Échauffements : R', 'mini-stats': 'Échauffements : stats', 'mini-eco': 'Échauffements : économétrie', 'mini-macro': 'Échauffements : Macro', 'mini-micro': 'Échauffements : Micro', 'mini-ineq': 'Échauffements : inégalités', 'mini-hist': 'Échauffements : histoire',  'r-graph': 'R : graphiques', seg: 'Ségrégation', ineq: 'Inégalités' };
const PREP = { 'micro-cpp': 'mini-micro', 'micro-pouvoir': 'mini-micro', 'stats-est': 'mini-stats', 'stats-desc': 'mini-stats', 'stats-tests': 'mini-stats',
  eco: 'mini-eco', 'con-dette': 'mini-macro', 'con-prix': 'mini-macro', 'con-croiss': 'mini-macro', 'con-travail': 'mini-macro', 'con-monnaie': 'mini-macro',
  'con-commerce': 'mini-macro', seg: 'mini-ineq', ineq: 'mini-ineq', 'r-base': 'mini-r', 'r-graph': 'mini-r' };
const trackOf = (t) => DATA.exercises.filter((e) => e.track === t).sort((a, b) => a.step - b.step);
// une marche est accessible quand toutes les précédentes de sa piste ont été réussies au moins une fois
const unlocked = (e) => !e.track || trackOf(e.track).filter((x) => x.step < e.step).every((x) => S.done[x.id] || S.paid[x.id]);
function chooseExercise(salt = 0, short = false) {
  const m = mastery(), t = ymd(), weekend = dayRank();
  const cutoff = ymd(addDays(new Date(), -14));
  const open = DATA.exercises.filter(unlocked).filter((e) => !short || e.minutes <= 5);
  const cand = open.filter((e) => !S.done[e.id] || S.done[e.id] < cutoff);
  const pool = cand.length ? cand : (open.length ? open : DATA.exercises);
  const w = pool.map((e) => (1.2 - (m[e.course] ?? 0)) * (S.done[e.id] ? 0.4 : 1) * (weekend && e.course === 'recherche' ? 3 : 1));
  const rnd = prng(hashStr(t + ':' + salt)), tot = w.reduce((a, b) => a + b, 0);
  let r = rnd() * tot;
  for (let i = 0; i < pool.length; i++) { r -= w[i]; if (r <= 0) return pool[i]; }
  return pool[pool.length - 1];
}
function mountExo(el) {
  let salt = 0, short = false;
  const draw = () => {
    const e = chooseExercise(salt, short);
    el.innerHTML = '';
    if (!e) { el.append(h('div', { class: 'dojo-panel' }, 'Aucun exercice dans le catalogue.')); return; }
    const done = h('div', { class: 'dojo-done', 'data-id': e.id });
    el.append(h('div', { class: 'dojo-panel' },
      h('div', {}, h('span', { class: 'dojo-badge red' }, COURSE_LABEL[e.course] || e.course),
        h('span', { class: 'dojo-badge' }, '★'.repeat(e.level) + '☆'.repeat(5 - e.level)),
        h('span', { class: 'dojo-badge' }, `~${e.minutes} min`), h('span', { class: 'dojo-badge gold' }, `+${e.xp} XP`),
        e.track ? h('span', { class: 'dojo-badge pine' }, `${TRACK_LABEL[e.track] || e.track} · marche ${e.step}/${trackOf(e.track).length}`) : ''),
      h('h4', { style: 'margin:.6rem 0' }, e.title),
      h('a', { class: 'dojo-btn primary', href: new URL(`${e.page}#${e.id}`, ROOT).href, style: 'text-decoration:none;display:inline-block' }, 'Ouvrir l\'exercice'),
      h('button', { class: 'dojo-btn', onclick: () => { salt++; draw(); } }, '🎲 Un autre'),
      h('button', { class: 'dojo-btn', title: 'Un échauffement de 5 minutes maximum', onclick: () => { short = !short; salt++; draw(); } }, short ? '↩ Tous les exercices' : '⚡ Plus court (≤ 5 min)'),
      h('p', { class: 'dojo-meta', style: 'margin:.7rem 0 .3rem' }, dayRank() ? 'Week-end : la recherche est mise en avant.' : 'Choisi selon tes points faibles (radar « Progression »).'),
      done));
    mountDone(done);
  };
  draw();
}

// ------------------------------------------------------------------ pistes (échelles de marches)
function mountTrack(el) {
  const t = el.dataset.track, list = trackOf(t);
  if (!list.length) return;
  const nDone = list.filter((x) => S.done[x.id]).length;
  el.append(h('div', { class: 'dojo-panel dojo-ladder' },
    h('div', {}, h('span', { class: 'dojo-badge red' }, 'piste'), h('strong', {}, ' ' + (TRACK_LABEL[t] || t)),
      h('span', { class: 'dojo-meta', style: 'margin-left:.6rem' }, `${nDone} / ${list.length} marches réussies`)),
    h('ol', { class: 'dojo-steps' }, ...list.map((x) => {
      const here = new URL(x.page, ROOT).pathname === location.pathname;
      const a = h('a', { href: here ? `#${x.id}` : new URL(`${x.page}#${x.id}`, ROOT).href }, x.title);
      return h('li', { class: S.done[x.id] ? 'ok' : (unlocked(x) ? 'next' : '') }, S.done[x.id] ? '✔ ' : '', a,
        h('span', { class: 'dojo-meta' }, ` · ${'★'.repeat(x.level)}`));
    })),
    PREP[t] ? h('p', { class: 'dojo-meta', style: 'margin:.6rem 0 0' }, 'Une marche te paraît trop haute ? ',
      h('a', { href: new URL(`parcours/minis.html#${PREP[t]}`, ROOT).href }, `Fais d'abord les échauffements (${trackOf(PREP[t]).length} mini-exercices, 2 à 5 min)`), '.') : ''));
}

// ------------------------------------------------------------------ défi de la semaine
function mountDefi(el) {
  const d = DATA.defi;
  if (!d) { el.append(h('div', { class: 'dojo-panel' }, 'Défi indisponible.')); return; }
  const done = h('div', { class: 'dojo-done', 'data-id': d.id, 'data-xp': d.xp });
  el.append(h('div', { class: 'dojo-panel' },
    h('div', {}, h('span', { class: 'dojo-badge red' }, 'défi de la semaine'),
      h('span', { class: 'dojo-badge' }, '★'.repeat(d.niveau) + '☆'.repeat(5 - d.niveau)),
      h('span', { class: 'dojo-badge' }, `~${d.minutes} min`), h('span', { class: 'dojo-badge gold' }, `+${d.xp} XP`)),
    h('h3', { style: 'margin:.6rem 0' }, d.titre),
    h('ul', {}, [].concat(d.enonce).map((x) => h('li', { html: fmt(x) }))),
    h('details', {}, h('summary', {}, 'Pistes'), h('p', { html: fmt(d.pistes || '') })),
    h('a', { class: 'dojo-btn primary', href: new URL(d.page, ROOT).href, style: 'text-decoration:none;display:inline-block' }, 'Ouvrir le labo'),
    h('a', { class: 'dojo-btn', href: new URL(`recherche/defis.html#${d.id}`, ROOT).href, style: 'text-decoration:none;display:inline-block;margin-left:.4rem' }, 'Voir le corrigé'), done));
  mountDone(done);
}

// ------------------------------------------------------------------ veille
function mountVeille(el) {
  const n = +el.dataset.n || 3, items = (DATA.veille || []).slice(0, n);
  if (!items.length) {
    el.append(h('div', { class: 'dojo-panel' }, h('p', { class: 'dojo-meta' },
      'La veille n\'a pas encore été récupérée (lance scripts/update_veille.R puis quarto render). En attendant, lis une référence du socle sur la page '),
      h('a', { href: new URL('veille.html', ROOT).href }, 'Veille'), '.'));
    return;
  }
  el.append(h('div', { class: 'dojo-panel' }, ...items.map((it) => h('div', { class: 'dojo-item' },
    h('a', { class: 't', href: it.url, target: '_blank', rel: 'noopener' }, it.title),
    h('div', { class: 'm' }, `${[].concat(it.authors || []).slice(0, 3).join(', ')}${(it.authors || []).length > 3 ? ' et al.' : ''} · ${it.venue || it.source} · ${it.date}`),
    h('div', {}, h('span', { class: 'dojo-badge pine' }, it.topic), h('span', { class: 'dojo-badge' }, 'score ' + it.score))))));
}

// ------------------------------------------------------------------ progression
function radar(m) {
  const keys = (DATA.courses || []).filter((c) => c in m), N = keys.length, R = 95, cx = 140, cy = 125;
  const pt = (i, r) => [cx + r * Math.sin(2 * Math.PI * i / N), cy - r * Math.cos(2 * Math.PI * i / N)];
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg'); svg.setAttribute('viewBox', '0 0 280 250'); svg.setAttribute('class', 'dojo-radar');
  const add = (tag, attrs, txt) => { const e = document.createElementNS(ns, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (txt) e.textContent = txt; svg.append(e); };
  for (const f of [0.25, 0.5, 0.75, 1]) add('polygon', { class: 'ring', points: keys.map((_, i) => pt(i, R * f).join(',')).join(' ') });
  keys.forEach((k, i) => { const [x, y] = pt(i, R); add('line', { class: 'axis', x1: cx, y1: cy, x2: x, y2: y });
    const [tx, ty] = pt(i, R + 16); add('text', { x: tx, y: ty + 4, 'text-anchor': tx < cx - 5 ? 'end' : tx > cx + 5 ? 'start' : 'middle' }, COURSE_LABEL[k] || k); });
  add('polygon', { class: 'shape', points: keys.map((k, i) => pt(i, R * Math.max(0.03, m[k])).join(',')).join(' ') });
  return svg;
}
function mountProgress(el) {
  const m = mastery(), i = beltIndex(), b = BELTS[i], nxt = BELTS[i + 1];
  const pct = nxt ? Math.round(100 * (S.xp - b.at) / (nxt.at - b.at)) : 100;
  const nCards = Object.keys(S.cards).length, mastered = Object.values(S.cards).filter((c) => c.box >= 3).length;
  const tiles = h('div', { class: 'dojo-grid' },
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Niveau'), h('div', { class: 'v' }, `${b.emoji} ${S.xp} XP`), h('div', { class: 's' }, b.name)),
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Série'), h('div', { class: 'v' }, `🔥 ${liveStreak()} j`), h('div', { class: 's' }, `record : ${S.bestStreak} j`)),
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Cartes'), h('div', { class: 'v' }, `${mastered} / ${DATA.cards.length}`), h('div', { class: 's' }, `maîtrisées (${nCards} vues)`)),
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Exercices'), h('div', { class: 'v' }, `${Object.keys(S.done).length}`), h('div', { class: 's' }, 'réussis (exercices et défis)')));
  const bar = h('div', {}, h('div', { class: 'dojo-meta' }, nxt ? `${nxt.at - S.xp} XP avant « ${nxt.name} »` : 'Niveau maximal atteint.'),
    h('div', { class: 'dojo-progressline' }, h('i', { style: `width:${pct}%` })));
  const rows = (DATA.courses || []).map((c) => {
    const cards = DATA.cards.filter((x) => x.course === c), ex = DATA.exercises.filter((x) => x.course === c), qz = DATA.quiz.filter((x) => x.course === c);
    return h('tr', {}, h('td', {}, COURSE_LABEL[c] || c),
      h('td', {}, `${cards.filter((x) => (S.cards[x.id]?.box ?? 0) >= 3).length}/${cards.length}`),
      h('td', {}, qz.length ? `${qz.filter((x) => S.quiz[x.id]?.last === 1).length}/${qz.length}` : '–'),
      h('td', {}, ex.length ? `${ex.filter((x) => S.done[x.id]).length}/${ex.length}` : '–'),
      h('td', {}, Math.round(100 * m[c]) + ' %'));
  });
  const heat = h('div', { class: 'dojo-heat' }, ...Array.from({ length: 30 }, (_, k) => {
    const d = ymd(addDays(new Date(), k - 29)), x = S.days[d] || 0;
    return h('i', { 'data-l': x === 0 ? 0 : x < 15 ? 1 : x < 40 ? 2 : 3, title: `${d} : ${x} XP` });
  }));
  const dl = () => { const a = h('a', { href: URL.createObjectURL(new Blob([JSON.stringify(S, null, 2)], { type: 'application/json' })), download: `dojo-progression-${ymd()}.json` }); a.click(); };
  const file = h('input', { type: 'file', accept: 'application/json', hidden: true, onchange: async (e) => {
    try { const j = JSON.parse(await e.target.files[0].text()); if (j.v !== 1) throw new Error('format'); S = Object.assign(fresh(), j); save(); location.reload(); }
    catch { alert('Fichier de progression invalide.'); } } });
  el.append(tiles, bar,
    h('div', { class: 'dojo-grid', style: 'grid-template-columns:minmax(260px,320px) 1fr;align-items:start' },
      h('div', { class: 'dojo-panel' }, h('h4', {}, 'Radar de maîtrise'), radar(m)),
      h('div', { class: 'dojo-panel' }, h('h4', {}, 'Par cours'),
        h('table', { class: 'dojo-table' }, h('thead', {}, h('tr', {}, ...['Cours', 'Cartes', 'QCM', 'Exercices', 'Maîtrise'].map((t) => h('th', {}, t)))), h('tbody', {}, ...rows)),
        h('p', { class: 'dojo-meta' }, 'Maîtrise = moyenne de : cartes en boîte ≥ 3, QCM réussis au dernier essai, exercices réussis.'))),
    h('div', { class: 'dojo-panel' }, h('h4', {}, '30 derniers jours'), heat),
    h('div', { class: 'dojo-panel' }, h('h4', {}, 'Sauvegarde'),
      h('p', { class: 'dojo-meta' }, 'Ta progression est stockée uniquement dans ce navigateur. Exporte-la pour la sauvegarder ou la transférer vers un autre appareil.'),
      h('button', { class: 'dojo-btn', onclick: dl }, 'Exporter (JSON)'),
      h('button', { class: 'dojo-btn', onclick: () => file.click() }, 'Importer'), file,
      h('button', { class: 'dojo-btn ko', onclick: () => { if (confirm('Effacer toute la progression ?')) { S = fresh(); save(); location.reload(); } } }, 'Tout réinitialiser')));
}

// ------------------------------------------------------------------ plan du jour (vignettes)
function mountPlan(el) {
  const t = ymd(), xpToday = S.days[t] || 0, due = DATA.cards.filter((c) => S.cards[c.id] && S.cards[c.id].due <= t).length;
  el.append(h('div', { class: 'dojo-grid' },
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Aujourd\'hui'), h('div', { class: 'v' }, `${xpToday} XP`), h('div', { class: 's' }, xpToday >= 20 ? '✔ séance validée' : 'objectif : 20 XP')),
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Cartes à réviser'), h('div', { class: 'v' }, String(due)), h('div', { class: 's' }, 'dues aujourd\'hui')),
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Série'), h('div', { class: 'v' }, `🔥 ${liveStreak()} j`), h('div', { class: 's' }, 'jours consécutifs')),
    h('div', { class: 'dojo-tile' }, h('div', { class: 'k' }, 'Ceinture'), h('div', { class: 'v' }, BELTS[beltIndex()].emoji + ' ' + BELTS[beltIndex()].name.split(' · ')[1]), h('div', { class: 's' }, `${S.xp} XP`))));
}

// ------------------------------------------------------------------ montage
const mounts = { '.dojo-plan': mountPlan, '.dojo-cards': mountCards, '.dojo-quiz': mountQuiz, '.dojo-exo': mountExo, '.dojo-defi': mountDefi,
  '.dojo-veille': mountVeille, '.dojo-progress': mountProgress, '.dojo-track': mountTrack };
renderChip();
for (const [sel, fn] of Object.entries(mounts)) $$(sel).forEach(fn);
$$('.dojo-done').filter((e) => !e.children.length).forEach(mountDone);
if (document.querySelector('.dojo-lab')) import('./lab.js').then((m) => m.mountLabs());
window.dojo = { S: () => S, addXP, DATA };           // utile pour déboguer dans la console
