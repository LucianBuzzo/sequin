#!/usr/bin/env node
/* Mint nightly reward manifest directly into ledger state and append reward block. */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = process.cwd();
const blocksDir = path.join(root, 'ledger', 'blocks');
const balancesPath = path.join(root, 'ledger', 'state', 'balances.json');
const metaPath = path.join(root, 'ledger', 'state', 'meta.json');
const appliedPath = path.join(root, 'ledger', 'state', 'reward_epochs.json');

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function writeJson(p, obj) {
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

function fail(msg) {
  console.error(`❌ ${msg}`);
  process.exit(1);
}

const date = arg('--date') || new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
const rewardPath = path.join(root, 'rewards', `${date}.json`);
if (!fs.existsSync(rewardPath)) fail(`Missing reward manifest: ${rewardPath}`);

const cfgPath = path.join(root, 'config', 'reward-repos.json');
const cfg = fs.existsSync(cfgPath) ? readJson(cfgPath) : {};

const reward = readJson(rewardPath);
if (!Array.isArray(reward.rewards)) fail('Reward manifest missing rewards array');
if (!reward.totals || typeof reward.totals !== 'object') fail('Reward manifest missing totals');

const balances = fs.existsSync(balancesPath) ? readJson(balancesPath) : {};
const meta = fs.existsSync(metaPath)
  ? readJson(metaPath)
  : { chain: 'sequin-github', version: 1, lastHeight: 0, lastUpdated: null };
const applied = fs.existsSync(appliedPath) ? readJson(appliedPath) : [];

if (applied.includes(date)) {
  console.log(`Reward epoch ${date} already minted; nothing to do.`);
  process.exit(0);
}

const distributed = reward.rewards.reduce((acc, r) => acc + (Number.isInteger(r.amount) ? r.amount : 0), 0);
const expectedEmission = Number.isInteger(reward.totals.dailyEmission)
  ? reward.totals.dailyEmission
  : Number.isInteger(cfg.dailyEmission)
    ? cfg.dailyEmission
    : null;
if (expectedEmission !== null && distributed > expectedEmission) {
  fail(`Distributed rewards ${distributed} exceed emission cap ${expectedEmission}`);
}

const maxRewardPerUser = Number.isInteger(cfg.maxRewardPerUser) ? cfg.maxRewardPerUser : null;
if (maxRewardPerUser !== null) {
  const violator = reward.rewards.find((r) => Number.isInteger(r.amount) && r.amount > maxRewardPerUser);
  if (violator) {
    fail(`Reward ${violator.amount} for ${violator.github} exceeds per-user cap ${maxRewardPerUser}`);
  }
}

for (const r of reward.rewards) {
  if (!r.github || !Number.isInteger(r.amount) || r.amount < 0) {
    fail(`Invalid reward row: ${JSON.stringify(r)}`);
  }
  if (r.amount > 0) {
    balances[r.github] = (balances[r.github] || 0) + r.amount;
  }
}

const nextHeight = (meta.lastHeight || 0) + 1;
const prevBlockPath = path.join(blocksDir, `${String(meta.lastHeight || 0).padStart(6, '0')}.json`);
const prevHash = fs.existsSync(prevBlockPath)
  ? crypto.createHash('sha256').update(fs.readFileSync(prevBlockPath)).digest('hex')
  : null;

const block = {
  height: nextHeight,
  prevHash,
  txIds: reward.rewards.filter((r) => r.amount > 0).map((r) => `reward:${date}:${r.github}`),
  timestamp: new Date().toISOString(),
  proposer: 'github-actions[bot]'
};

const blockPath = path.join(blocksDir, `${String(nextHeight).padStart(6, '0')}.json`);
writeJson(blockPath, block);
writeJson(balancesPath, balances);

meta.lastHeight = nextHeight;
meta.lastUpdated = new Date().toISOString();
writeJson(metaPath, meta);

applied.push(date);
writeJson(appliedPath, applied);

console.log(`✅ Minted reward epoch ${date} in block #${nextHeight}`);
