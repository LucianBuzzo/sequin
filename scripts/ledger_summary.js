#!/usr/bin/env node
/* Print quick ledger summary and recent reward epochs. */
const fs = require('fs');
const path = require('path');

const root = process.cwd();

function readJson(p, fallback) {
  if (!fs.existsSync(p)) return fallback;
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const topN = Number(arg('--top') || 10);
const epochs = Number(arg('--epochs') || 5);

const balances = readJson(path.join(root, 'ledger', 'state', 'balances.json'), {});
const meta = readJson(path.join(root, 'ledger', 'state', 'meta.json'), {});
const minted = readJson(path.join(root, 'ledger', 'state', 'reward_epochs.json'), []);

const top = Object.entries(balances)
  .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
  .slice(0, topN);

console.log(`Chain: ${meta.chain || 'unknown'} v${meta.version || '?'} | tip=${meta.lastHeight ?? '?'}`);
console.log(`Last updated: ${meta.lastUpdated || 'n/a'}`);
console.log('');
console.log(`Top ${top.length} balances:`);
for (const [user, amount] of top) {
  console.log(`- ${user}: ${amount}`);
}

console.log('');
console.log(`Recent minted reward epochs (${Math.min(epochs, minted.length)}/${minted.length}):`);
for (const e of minted.slice(-epochs).reverse()) {
  console.log(`- ${e}`);
}
