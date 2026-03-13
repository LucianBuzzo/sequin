#!/usr/bin/env node
/* Lightweight repo linting for CI reliability. */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = process.cwd();
const includeDirs = ['schemas', 'ledger', 'wallets', 'tx', 'rewards', 'config'];

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const name of fs.readdirSync(dir)) {
    if (name === '.git' || name === 'node_modules' || name === '.sequin') continue;
    const p = path.join(dir, name);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

function fail(msg) {
  console.error(`❌ ${msg}`);
  process.exit(1);
}

let checkedJson = 0;
for (const d of includeDirs) {
  const abs = path.join(root, d);
  const files = walk(abs).filter((p) => p.endsWith('.json'));
  for (const f of files) {
    try {
      JSON.parse(fs.readFileSync(f, 'utf8'));
      checkedJson += 1;
    } catch (e) {
      fail(`Invalid JSON in ${path.relative(root, f)}: ${e.message}`);
    }
  }
}

const jsFiles = walk(path.join(root, 'scripts')).filter((p) => p.endsWith('.js'));
for (const f of jsFiles) {
  const src = fs.readFileSync(f, 'utf8');
  try {
    new vm.Script(src, { filename: f });
  } catch (e) {
    fail(`Invalid JS syntax in ${path.relative(root, f)}: ${e.message}`);
  }
}

console.log(`✅ JSON files checked: ${checkedJson}`);
console.log(`✅ JS files syntax-checked: ${jsFiles.length}`);
