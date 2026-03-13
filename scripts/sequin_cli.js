#!/usr/bin/env node
/* Minimal local helper for GitHub-native Sequin wallet + tx signing. */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = process.cwd();

function usage() {
  console.log(`
Usage:
  node scripts/sequin_cli.js wallet:create --github <username>
  node scripts/sequin_cli.js tx:sign --from <username> --to <username> --amount <int> --nonce <int> [--memo "..."]

Notes:
  - Private keys are stored locally under .sequin/keys/<username>.key (gitignored).
  - Public wallet files are written to wallets/<username>.json for PR registration.
  - Signed tx files are written to tx/pending/<timestamp>__<id>.json
`);
}

function arg(name, required = false) {
  const i = process.argv.indexOf(name);
  const val = i >= 0 ? process.argv[i + 1] : undefined;
  if (required && !val) throw new Error(`Missing required arg ${name}`);
  return val;
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function b64(buf) {
  return Buffer.from(buf).toString('base64');
}

function canonicalTx(tx) {
  return JSON.stringify({
    id: tx.id,
    from: tx.from,
    to: tx.to,
    amount: tx.amount,
    nonce: tx.nonce,
    memo: tx.memo || '',
    createdAt: tx.createdAt,
  });
}

function cmdWalletCreate() {
  const github = arg('--github', true);
  const keysDir = path.join(root, '.sequin', 'keys');
  ensureDir(keysDir);
  ensureDir(path.join(root, 'wallets'));

  const keyPath = path.join(keysDir, `${github}.key`);
  if (fs.existsSync(keyPath)) throw new Error(`Private key already exists: ${keyPath}`);

  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const pkcs8 = privateKey.export({ format: 'pem', type: 'pkcs8' });
  fs.writeFileSync(keyPath, pkcs8, { mode: 0o600 });

  const jwk = publicKey.export({ format: 'jwk' });
  const rawPub = Buffer.from(jwk.x, 'base64url');
  if (rawPub.length !== 32) throw new Error('Unexpected pubkey length');

  const wallet = {
    github,
    pubkey: `ed25519:${b64(rawPub)}`,
    createdAt: new Date().toISOString(),
  };

  const walletPath = path.join(root, 'wallets', `${github}.json`);
  fs.writeFileSync(walletPath, JSON.stringify(wallet, null, 2) + '\n');

  console.log(`✅ Created wallet file: ${walletPath}`);
  console.log(`✅ Created private key: ${keyPath}`);
  console.log('⚠️ Keep private key secret. Do NOT commit .sequin/keys/*');
}

function txId() {
  return crypto.randomBytes(8).toString('hex');
}

function cmdTxSign() {
  const from = arg('--from', true);
  const to = arg('--to', true);
  const amount = Number(arg('--amount', true));
  const nonce = Number(arg('--nonce', true));
  const memo = arg('--memo', false) || '';

  if (!Number.isInteger(amount) || amount < 1) throw new Error('--amount must be integer >= 1');
  if (!Number.isInteger(nonce) || nonce < 1) throw new Error('--nonce must be integer >= 1');

  const keyPath = path.join(root, '.sequin', 'keys', `${from}.key`);
  if (!fs.existsSync(keyPath)) throw new Error(`Missing private key for ${from}: ${keyPath}`);
  const privateKeyPem = fs.readFileSync(keyPath, 'utf8');
  const privateKey = crypto.createPrivateKey(privateKeyPem);

  ensureDir(path.join(root, 'tx', 'pending'));

  const tx = {
    id: txId(),
    from,
    to,
    amount,
    nonce,
    memo,
    createdAt: new Date().toISOString(),
  };

  const payload = canonicalTx(tx);
  const sig = crypto.sign(null, Buffer.from(payload, 'utf8'), privateKey);
  tx.signature = b64(sig);

  const stamp = tx.createdAt.replace(/[:.]/g, '-');
  const out = path.join(root, 'tx', 'pending', `${stamp}__${tx.id}.json`);
  fs.writeFileSync(out, JSON.stringify(tx, null, 2) + '\n');

  console.log(`✅ Signed tx written: ${out}`);
  console.log(`   from=${from} to=${to} amount=${amount} nonce=${nonce}`);
}

function main() {
  const cmd = process.argv[2];
  if (!cmd || cmd === '-h' || cmd === '--help') {
    usage();
    return;
  }

  if (cmd === 'wallet:create') return cmdWalletCreate();
  if (cmd === 'tx:sign') return cmdTxSign();

  throw new Error(`Unknown command: ${cmd}`);
}

try {
  main();
} catch (e) {
  console.error(`❌ ${e.message}`);
  process.exit(1);
}
