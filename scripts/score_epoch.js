#!/usr/bin/env node
/*
 * Generate daily Proof-of-PR reward manifest.
 *
 * Usage:
 *   GITHUB_TOKEN=... node scripts/score_epoch.js --date 2026-03-13
 */
const fs = require('fs');
const path = require('path');

const root = process.cwd();
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'config', 'reward-repos.json'), 'utf8'));

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const date = arg('--date') || new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
const token = process.env.GITHUB_TOKEN;
const epochStartUtc = `${date}T00:00:00Z`;
const epochEndUtc = `${date}T23:59:59Z`;

function scorePR(pr) {
  const lines = (pr.additions || 0) + (pr.deletions || 0);
  // Medium anti-gaming baseline: ignore tiny edits.
  if (lines < 10) return 0;

  const base = 10;
  const size = Math.min(20, Math.log(1 + lines) * 3.5);
  const files = Math.min(8, (pr.changed_files || 0) * 0.5);
  const selfMergePenalty = pr.merged_by?.login === pr.user?.login ? -6 : 0;
  const draftPenalty = pr.draft ? -5 : 0;
  return Math.max(0, base + size + files + selfMergePenalty + draftPenalty);
}

async function gh(pathname) {
  const res = await fetch(`https://api.github.com${pathname}`, {
    headers: {
      'Accept': 'application/vnd.github+json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      'User-Agent': 'sequin-rewards-script'
    }
  });
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText} for ${pathname}`);
  }
  return res.json();
}

async function mergedPRNumbers(repo) {
  // Search issues endpoint for merged PRs in the UTC epoch day window.
  const q = encodeURIComponent(`repo:${repo} is:pr is:merged merged:${date}..${date}`);
  const data = await gh(`/search/issues?q=${q}&per_page=100`);
  return (data.items || []).map((item) => {
    const parts = item.pull_request?.url?.split('/');
    const number = Number(parts?.[parts.length - 1]);
    return Number.isInteger(number) ? number : null;
  }).filter(Boolean);
}

async function loadPR(repo, number) {
  const [owner, name] = repo.split('/');
  return gh(`/repos/${owner}/${name}/pulls/${number}`);
}

async function main() {
  const points = new Map();
  const detail = [];

  for (const repo of cfg.repos) {
    const numbers = await mergedPRNumbers(repo);
    for (const num of numbers) {
      const pr = await loadPR(repo, num);
      const login = pr.user?.login;
      if (!login) continue;
      if ((cfg.excludeLogins || []).includes(login)) continue;

      const s = scorePR(pr);
      detail.push({
        repo,
        number: pr.number,
        title: pr.title,
        login,
        score: Number(s.toFixed(2)),
        additions: pr.additions,
        deletions: pr.deletions,
        changed_files: pr.changed_files,
        merged_by: pr.merged_by?.login || null
      });
    }
  }

  // Group by login and cap by top N PRs.
  const byUser = new Map();
  for (const d of detail) {
    if (!byUser.has(d.login)) byUser.set(d.login, []);
    byUser.get(d.login).push(d);
  }

  for (const [login, arr] of byUser.entries()) {
    arr.sort((a, b) => b.score - a.score);
    const top = arr.slice(0, cfg.maxPRsPerUser || 5);
    const total = top.reduce((acc, x) => acc + x.score, 0);
    points.set(login, Math.min(cfg.maxScorePerUser || 120, total));
  }

  const mergedPrCount = detail.length;
  const day = new Date(`${date}T00:00:00Z`).getUTCDay(); // 0=Sun..6=Sat
  const isWeekday = day >= 1 && day <= 5;
  if ((cfg.abortIfNoMergedPRsOnWeekday ?? true) && isWeekday && mergedPrCount === 0) {
    throw new Error(`No merged PR activity found for weekday epoch ${date}; aborting mint pipeline`);
  }

  const totalScore = Array.from(points.values()).reduce((a, b) => a + b, 0);
  const rewards = [];
  if (totalScore > 0) {
    for (const [login, score] of points.entries()) {
      const amount = Math.floor((cfg.dailyEmission * score) / totalScore);
      if (amount > 0) rewards.push({ github: login, amount, score: Number(score.toFixed(2)) });
    }
    rewards.sort((a, b) => b.amount - a.amount || a.github.localeCompare(b.github));
  }

  const out = {
    epoch: date,
    epochStartUtc,
    epochEndUtc,
    generatedAt: new Date().toISOString(),
    config: {
      repos: cfg.repos,
      dailyEmission: cfg.dailyEmission,
      maxPRsPerUser: cfg.maxPRsPerUser,
      maxScorePerUser: cfg.maxScorePerUser
    },
    totals: {
      contributors: rewards.length,
      mergedPrCount,
      totalScore: Number(totalScore.toFixed(2)),
      dailyEmission: cfg.dailyEmission,
      distributed: rewards.reduce((a, r) => a + r.amount, 0)
    },
    rewards,
    details: detail
  };

  fs.mkdirSync(path.join(root, 'rewards'), { recursive: true });
  const outPath = path.join(root, 'rewards', `${date}.json`);
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n');
  console.log(`Wrote ${outPath}`);
}

main().catch((e) => {
  console.error(`❌ ${e.message}`);
  process.exit(1);
});
