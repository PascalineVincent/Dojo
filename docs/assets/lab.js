// Laboratoire interactif : structures de marché (demande linéaire, coût marginal constant).
// Monté sur <div class="dojo-lab" data-lab="market"></div>
import { market } from './market.js';

const NS = 'http://www.w3.org/2000/svg';
const f = (x) => (Math.abs(x) >= 100 ? x.toFixed(0) : x.toFixed(1));

export function mountLabs() {
  document.querySelectorAll('.dojo-lab[data-lab="market"]').forEach(mountMarket);
}

function mountMarket(root) {
  const state = { A: 100, b: 2, c: 20, N: 3, s: 'monopole' };
  const defs = [['A', 'Demande (ordonnée)', 40, 200, 5], ['b', 'Pente b', 0.5, 5, 0.5], ['c', 'Coût marginal', 0, 80, 1], ['N', 'N (Cournot)', 2, 10, 1]];
  const names = { cpp: 'Concurrence parfaite / Bertrand', monopole: 'Monopole', cournot: 'Cournot (N firmes)', stackelberg: 'Stackelberg' };

  const panel = document.createElement('div');
  const sel = document.createElement('select');
  sel.className = 'form-select form-select-sm';
  for (const [k, v] of Object.entries(names)) sel.add(new Option(v, k, false, k === state.s));
  sel.onchange = () => { state.s = sel.value; draw(); };
  panel.append(sel);
  const outs = {};
  for (const [k, label, min, max, step] of defs) {
    const lab = document.createElement('label');
    const val = document.createElement('span');
    const inp = Object.assign(document.createElement('input'), { type: 'range', min, max, step, value: state[k] });
    inp.oninput = () => { state[k] = +inp.value; draw(); };
    outs[k] = val;
    lab.append(label, inp, val); panel.append(lab);
  }
  const table = document.createElement('table'); table.className = 'out'; panel.append(table);
  const svg = document.createElementNS(NS, 'svg'); svg.setAttribute('viewBox', '0 0 520 360');
  root.append(panel, svg);

  const W = 520, H = 360, ml = 46, mb = 34, mt = 14, mr = 14;
  function draw() {
    state.c = Math.min(state.c, state.A - 10);
    const { A, b, c, N } = state;
    for (const [k] of defs) outs[k].textContent = state[k];
    const r = market({ A, b, c, N })[state.s];
    const Qc = (A - c) / b, Qmax = A / b;
    const X = (q) => ml + (q / Qmax) * (W - ml - mr), Y = (p) => H - mb - (p / A) * (H - mb - mt);
    const poly = (cls, pts) => `<polygon class="${cls}" points="${pts.map(([q, p]) => `${X(q)},${Y(p)}`).join(' ')}"/>`;
    const line = (cls, [q1, p1], [q2, p2]) => `<line class="${cls}" x1="${X(q1)}" y1="${Y(p1)}" x2="${X(q2)}" y2="${Y(p2)}"/>`;
    let s = '';
    s += poly('cs', [[0, A], [0, r.P], [r.Q, r.P]]);
    s += poly('ps', [[0, r.P], [r.Q, r.P], [r.Q, c], [0, c]]);
    if (r.DWL > 1e-9) s += poly('dwl', [[r.Q, r.P], [r.Q, c], [Qc, c]]);
    s += line('grid', [0, 0], [Qmax, 0]) + line('grid', [0, 0], [0, A]);
    s += line('demand', [0, A], [Qmax, 0]) + line('mc', [0, c], [Qmax, c]);
    if (state.s === 'monopole') s += line('mr', [0, A], [Qmax / 2, 0]);
    s += `<circle cx="${X(r.Q)}" cy="${Y(r.P)}" r="4.5" fill="var(--d-ink)"/>`;
    s += `<text x="${W - mr}" y="${H - 8}" text-anchor="end">Quantité Q</text><text x="6" y="${mt + 4}">Prix</text>`;
    s += `<text x="${X(Qmax) - 4}" y="${Y(0) - 10}" text-anchor="end" fill="var(--d-red)">Demande</text>`;
    s += `<text x="${X(Qmax) - 4}" y="${Y(c) - 6}" text-anchor="end" fill="var(--d-pine)">Cm = ${c}</text>`;
    svg.innerHTML = s;
    const row = (k, v) => `<tr><td>${k}</td><td><b>${v}</b></td></tr>`;
    table.innerHTML = row('Quantité Q', f(r.Q)) + row('Prix P', f(r.P)) + row('Profit total', f(r.profit))
      + row('Surplus consommateur', f(r.CS)) + row('Surplus total', f(r.SW)) + row('Perte sèche', f(r.DWL))
      + (r.q_i !== undefined ? row('Quantité par firme', f(r.q_i)) : '')
      + (r.q_leader !== undefined ? row('Leader / suiveur', `${f(r.q_leader)} / ${f(r.q_follower)}`) : '');
  }
  draw();
}
