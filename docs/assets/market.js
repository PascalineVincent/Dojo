// Structures de marché à demande linéaire P = A - b Q et coût marginal constant c.
// Module ES (navigateur + Node pour les tests). Renvoie quantités, prix, surplus et perte sèche.

export function market({ A, b, c, N = 2 }) {
  const Qc = (A - c) / b;                            // quantité concurrentielle
  const out = (name, Q, extra = {}) => {
    const P = A - b * Q;
    const CS = 0.5 * Q * (A - P);
    const profit = (P - c) * Q;                      // profit total (coût fixe nul)
    const SW = CS + profit;
    const SWc = 0.5 * Qc * (A - c);
    return { name, Q, P, CS, profit, SW, DWL: SWc - SW, ...extra };
  };
  const res = {};
  res.cpp = out("Concurrence parfaite / Bertrand", Qc);
  res.monopole = out("Monopole", Qc / 2);
  res.cournot = out(`Cournot (N=${N})`, (N / (N + 1)) * Qc, { q_i: Qc / (N + 1) });
  // Stackelberg : un leader, un suiveur
  const qL = Qc / 2, qF = Qc / 4;
  res.stackelberg = out("Stackelberg (1 leader, 1 suiveur)", qL + qF, { q_leader: qL, q_follower: qF });
  return res;
}
