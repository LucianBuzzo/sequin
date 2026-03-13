#!/usr/bin/env node
/*
 * Deterministic validator for wallet + pending tx files.
 * Includes Ed25519 signature verification using canonical payload bytes.
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

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
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .sort()
    .map((f) => path.join(dir, f));
}

function fail(msg) {
  console.error(`❌ ${msg}`);
  process.exit(1);
}

function ok(msg) {
  console.log(`✅ ${msg}`);
}

function canonicalTxPayload(tx) {
  return {
    id: tx.id,
    from: tx.from,
    to: tx.to,
    amount: tx.amount,
    nonce: tx.nonce,
    memo: tx.memo || '',
    createdAt: tx.createdAt,
  };
}

function canonicalTxString(tx) {
  return JSON.stringify(canonicalTxPayload(tx));
}

function txHash(tx) {
  return crypto.createHash('sha256').update(canonicalTxString(tx)).digest('hex');
}

// Build SPKI DER for Ed25519 from raw 32-byte public key.
// Prefix bytes for id-Ed25519 subjectPublicKeyInfo.
function ed25519KeyObjectFromRaw(raw32) {
  if (!Buffer.isBuffer(raw32) || raw32.length !== 32) {
    throw new Error('raw Ed25519 pubkey must be 32 bytes');
  }
  const prefix = Buffer.from('302a300506032b6570032100', 'hex');
  const spkiDer = Buffer.concat([prefix, raw32]);
  return crypto.createPublicKey({ key: spkiDer, format: 'der', type: 'spki' });
}

function parseWalletPubkey(pubkey) {
  if (typeof pubkey !== 'string' || !pubkey.startsWith('ed25519:')) {
    throw new Error('pubkey must be prefixed with ed25519:');
  }
  const b64 = pubkey.slice('ed25519:'.length);
  const raw = Buffer.from(b64, 'base64');
  if (raw.length !== 32) {
    throw new Error('ed25519 public key must decode to 32 bytes');
  }
  return ed25519KeyObjectFromRaw(raw);
}

function verifySignature(tx, wallet) {
  const payload = canonicalTxString(tx);
  const sig = Buffer.from(tx.signature, 'base64');
  if (sig.length !== 64) {
    throw new Error('signature must decode to 64 bytes (ed25519)');
  }
  const pub = parseWalletPubkey(wallet.pubkey);
  const verified = crypto.verify(null, Buffer.from(payload, 'utf8'), pub, sig);
  return verified;
}

const balances = fs.existsSync(balancesPath) ? readJson(balancesPath) : {};
const nonces = fs.existsSync(noncesPath) ? readJson(noncesPath) : {};

const walletFiles = listJsonFiles(walletsDir);
const wallets = new Map();
const pubkeys = new Set();
for (const wf of walletFiles) {
  const w = readJson(wf);
  const filename = path.basename(wf, '.json');
  if (filename !== w.github) fail(`Wallet filename ${filename}.json must match github field ${w.github}`);
  if (wallets.has(w.github)) fail(`Duplicate wallet for ${w.github}`);
  if (pubkeys.has(w.pubkey)) fail(`Duplicate public key for ${w.github}`);
  // Validate parse-ability of key material
  try {
    parseWalletPubkey(w.pubkey);
  } catch (e) {
    fail(`Invalid pubkey for ${w.github}: ${e.message}`);
  }
  wallets.set(w.github, w);
  pubkeys.add(w.pubkey);
}
ok(`Loaded ${wallets.size} wallet(s)`);

const txFiles = listJsonFiles(pendingDir);
const txIds = new Set();
const txHashes = new Set();
for (const tf of txFiles) {
  const tx = readJson(tf);
  const ctx = `${path.basename(tf)}`;

  const required = ['id', 'from', 'to', 'amount', 'nonce', 'createdAt', 'signature'];
  for (const key of required) if (!(key in tx)) fail(`${ctx}: missing ${key}`);

  if (txIds.has(tx.id)) fail(`${ctx}: duplicate tx id ${tx.id}`);
  txIds.add(tx.id);

  const hash = txHash(tx);
  if (txHashes.has(hash)) fail(`${ctx}: duplicate tx payload hash ${hash}`);
  txHashes.add(hash);

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

  try {
    const validSig = verifySignature(tx, wallets.get(tx.from));
    if (!validSig) fail(`${ctx}: signature verification failed`);
  } catch (e) {
    fail(`${ctx}: signature verification error: ${e.message}`);
  }

  // Simulate state progression for deterministic validation of tx order in this PR.
  nonces[tx.from] = tx.nonce;
  balances[tx.from] = bal - tx.amount;
  balances[tx.to] = (balances[tx.to] || 0) + tx.amount;
}

ok(`Validated ${txFiles.length} pending transaction(s)`);
