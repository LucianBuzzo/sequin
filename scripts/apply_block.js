#!/usr/bin/env node
/* Apply pending tx files into a new block and update state files. */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = process.cwd();
const blocksDir = path.join(root, 'ledger', 'blocks');
const balancesPath = path.join(root, 'ledger', 'state', 'balances.json');
const noncesPath = path.join(root, 'ledger', 'state', 'nonces.json');
const metaPath = path.join(root, 'ledger', 'state', 'meta.json');
const pendingDir = path.join(root, 'tx', 'pending');

function readJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }
function writeJson(p, obj) { fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n'); }

if (!fs.existsSync(blocksDir)) fs.mkdirSync(blocksDir, { recursive: true });

const pendingFiles = fs.existsSync(pendingDir)
  ? fs.readdirSync(pendingDir).filter((f) => f.endsWith('.json')).sort()
  : [];

if (!pendingFiles.length) {
  console.log('No pending tx files; nothing to apply.');
  process.exit(0);
}

const balances = fs.existsSync(balancesPath) ? readJson(balancesPath) : {};
const nonces = fs.existsSync(noncesPath) ? readJson(noncesPath) : {};
const meta = fs.existsSync(metaPath) ? readJson(metaPath) : { chain: 'sequin-github', version: 1, lastHeight: 0 };

const txs = pendingFiles.map((f) => ({ file: f, data: readJson(path.join(pendingDir, f)) }));
for (const { data: tx } of txs) {
  const fromBal = balances[tx.from] || 0;
  if (fromBal < tx.amount) throw new Error(`Insufficient balance for ${tx.from}`);
  const expectedNonce = (nonces[tx.from] || 0) + 1;
  if (tx.nonce !== expectedNonce) throw new Error(`Bad nonce for ${tx.from}: expected ${expectedNonce}, got ${tx.nonce}`);
  balances[tx.from] = fromBal - tx.amount;
  balances[tx.to] = (balances[tx.to] || 0) + tx.amount;
  nonces[tx.from] = tx.nonce;
}

const nextHeight = (meta.lastHeight || 0) + 1;
const prevBlockPath = path.join(blocksDir, `${String(meta.lastHeight || 0).padStart(6, '0')}.json`);
const prevHash = fs.existsSync(prevBlockPath)
  ? crypto.createHash('sha256').update(fs.readFileSync(prevBlockPath)).digest('hex')
  : null;

const block = {
  height: nextHeight,
  prevHash,
  txIds: txs.map((x) => x.data.id),
  timestamp: new Date().toISOString(),
  proposer: 'github-actions[bot]'
};

const blockPath = path.join(blocksDir, `${String(nextHeight).padStart(6, '0')}.json`);
writeJson(blockPath, block);
writeJson(balancesPath, balances);
writeJson(noncesPath, nonces);
meta.lastHeight = nextHeight;
meta.lastUpdated = new Date().toISOString();
writeJson(metaPath, meta);

for (const { file } of txs) fs.unlinkSync(path.join(pendingDir, file));

console.log(`Applied block #${nextHeight} with ${txs.length} tx(s)`);
