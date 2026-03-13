#!/usr/bin/env node
/*
 * Basic deterministic validator for wallet + pending tx files.
 * NOTE: Signature verification is intentionally TODO for V1 scaffold.
 */
const fs = require('fs');
const path = require('path');

const root = process.cwd();
const walletsDir = path.join(root, 'wallets');
const pendingDir = path.join(root, 'tx', 'pending');
const balancesPath = path.join(root, 'ledger', 'state', 'balances.json');
const noncesPath = path.join(root, 'ledger', 'state', 'nonces.json');

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function listJsonFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => path.join(dir, f));
}

function fail(msg) {
  console.error(`❌ ${msg}`);
  process.exit(1);
}

function ok(msg) {
  console.log(`✅ ${msg}`);
}

const balances = fs.existsSync(balancesPath) ? readJson(balancesPath) : {};
const nonces = fs.existsSync(noncesPath) ? readJson(noncesPath) : {};

const walletFiles = listJsonFiles(walletsDir);
const wallets = new Map();
for (const wf of walletFiles) {
  const w = readJson(wf);
  const filename = path.basename(wf, '.json');
  if (filename !== w.github) fail(`Wallet filename ${filename}.json must match github field ${w.github}`);
  if (wallets.has(w.github)) fail(`Duplicate wallet for ${w.github}`);
  wallets.set(w.github, w);
}
ok(`Loaded ${wallets.size} wallet(s)`);

const txFiles = listJsonFiles(pendingDir);
const txIds = new Set();
for (const tf of txFiles) {
  const tx = readJson(tf);
  const ctx = `${path.basename(tf)}`;

  const required = ['id', 'from', 'to', 'amount', 'nonce', 'createdAt', 'signature'];
  for (const key of required) if (!(key in tx)) fail(`${ctx}: missing ${key}`);

  if (txIds.has(tx.id)) fail(`${ctx}: duplicate tx id ${tx.id}`);
  txIds.add(tx.id);

  if (!wallets.has(tx.from)) fail(`${ctx}: sender wallet ${tx.from} not registered`);
  if (!wallets.has(tx.to)) fail(`${ctx}: receiver wallet ${tx.to} not registered`);
  if (!Number.isInteger(tx.amount) || tx.amount < 1) fail(`${ctx}: amount must be integer >= 1`);
  if (!Number.isInteger(tx.nonce) || tx.nonce < 1) fail(`${ctx}: nonce must be integer >= 1`);

  const expectedNonce = (nonces[tx.from] || 0) + 1;
  if (tx.nonce !== expectedNonce) {
    fail(`${ctx}: nonce mismatch for ${tx.from}; expected ${expectedNonce}, got ${tx.nonce}`);
  }

  const bal = balances[tx.from] || 0;
  if (bal < tx.amount) fail(`${ctx}: insufficient funds for ${tx.from}; have ${bal}, need ${tx.amount}`);

  // TODO: Verify tx.signature against wallets[from].pubkey using canonical payload bytes.
  if (typeof tx.signature !== 'string' || tx.signature.length < 16) {
    fail(`${ctx}: signature missing/invalid`);
  }

  // Simulate state progression for deterministic validation of tx order in this PR.
  nonces[tx.from] = tx.nonce;
  balances[tx.from] = bal - tx.amount;
  balances[tx.to] = (balances[tx.to] || 0) + tx.amount;
}

ok(`Validated ${txFiles.length} pending transaction(s)`);
console.log('ℹ️ Signature crypto verification: TODO in next step');
