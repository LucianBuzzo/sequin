#!/usr/bin/env node
/* Verify ledger block linkage and state metadata sanity. */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = process.cwd();
const blocksDir = path.join(root, 'ledger', 'blocks');
const metaPath = path.join(root, 'ledger', 'state', 'meta.json');

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function sha256File(p) {
  return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
}

function fail(msg) {
  console.error(`❌ ${msg}`);
  process.exit(1);
}

if (!fs.existsSync(blocksDir)) fail('Missing ledger/blocks directory');

const files = fs.readdirSync(blocksDir).filter((f) => f.endsWith('.json')).sort();
if (!files.length) fail('No block files found');

let prevHash = null;
let expectedHeight = 0;
for (const f of files) {
  const p = path.join(blocksDir, f);
  const b = readJson(p);

  if (b.height !== expectedHeight) {
    fail(`${f}: expected height ${expectedHeight}, found ${b.height}`);
  }

  if (b.prevHash !== prevHash) {
    fail(`${f}: prevHash mismatch, expected ${prevHash}, found ${b.prevHash}`);
  }

  prevHash = sha256File(p);
  expectedHeight += 1;
}

const tipHeight = expectedHeight - 1;
const meta = readJson(metaPath);
if (meta.lastHeight !== tipHeight) {
  fail(`meta.lastHeight mismatch: expected ${tipHeight}, found ${meta.lastHeight}`);
}

console.log(`✅ Chain valid (${files.length} blocks, tip=${tipHeight})`);
