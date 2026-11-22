import { market } from "../../assets/market.js";
const eq = (a, b, m) => { if (Math.abs(a - b) > 1e-9) throw new Error(`${m}: ${a} != ${b}`); };
const m = market({ A: 100, b: 2, c: 20, N: 3 });
eq(m.cpp.Q, 40, "Qc"); eq(m.cpp.P, 20, "Pc"); eq(m.cpp.DWL, 0, "DWL cpp");
eq(m.monopole.Q, 20, "Qm"); eq(m.monopole.P, 60, "Pm"); eq(m.monopole.profit, 800, "profit m");
eq(m.monopole.DWL, 0.5 * (60 - 20) * (40 - 20), "DWL m");
eq(m.cournot.Q, 30, "Q cournot N=3"); eq(m.cournot.P, (100 + 3 * 20) / 4, "P cournot");
eq(m.stackelberg.Q, 30, "Q stack"); eq(m.stackelberg.q_leader, 20, "qL"); eq(m.stackelberg.q_follower, 10, "qF");
// Cournot N=2 : Q = 2/3 Qc, P = (A+2c)/3
const d = market({ A: 100, b: 2, c: 20, N: 2 });
eq(d.cournot.P, (100 + 40) / 3, "P duopole");
// ordre des prix : cpp < cournot(2) < stackelberg < monopole ? (Stackelberg Q=3/4 Qc -> P = A - 3/4 b Qc)
if (!(m.cpp.P < d.stackelberg.P && d.stackelberg.P < d.cournot.P && d.cournot.P < m.monopole.P)) throw new Error("ordre des prix");
console.log("OK market");
