<div align="center">
  <img width="372" height="110" src="https://raw.githubusercontent.com/LucianBuzzo/sequin/master/sequin.png">
  <br>
  <br>

![GitHub last commit](https://img.shields.io/github/last-commit/lucianbuzzo/sequin)
![Validate TX](https://github.com/lucianbuzzo/sequin/actions/workflows/validate-tx.yml/badge.svg?branch=master)
![Nightly Rewards](https://github.com/lucianbuzzo/sequin/actions/workflows/nightly-rewards.yml/badge.svg?branch=master)

  <p>
  Sequin is a <strong>GitHub-native novelty cryptocurrency</strong>.
  </p>
  <p>
  No always-on server required: repo state is the ledger, PRs are transactions, and GitHub Actions validates + mints.
  </p>
  <br>
</div>

## What changed?

Sequin originally started as a Crystal server app.

It now follows a new design:

- **Ledger lives in git** (`ledger/`)
- **Wallets are registered by PR** (`wallets/<github-user>.json`)
- **Transfers are submitted by PR** (`tx/pending/*.json`)
- **Nightly rewards are generated from GitHub PR activity** (`rewards/YYYY-MM-DD.json`)
- **Rewards are auto-minted** into the ledger by GitHub Actions

`master` is the canonical chain.

---

## Repository layout

```txt
ledger/
  blocks/
  state/
wallets/
tx/pending/
rewards/
schemas/
scripts/
.github/workflows/
```

---

## How it works

### 1) Register a wallet

- Generate keypair locally (private key stays local)
- Commit `wallets/<your-github-username>.json`
- Open PR
- `validate-tx` must pass
- Merge PR to register wallet

### 2) Send sequins

- Create/sign tx JSON in `tx/pending/`
- Open PR
- `validate-tx` checks schema + signature + nonce + balance
  - signature payload is versioned (`sigVersion: 1`) for deterministic verification
- Merge PR
- `rebuild-ledger` applies tx into a new block and updates balances/nonces

### 3) Nightly rewards (Proof of PR)

`nightly-rewards` workflow:

1. Scores merged PR activity
2. Writes manifest `rewards/YYYY-MM-DD.json`
3. Auto-mints rewards into ledger state
4. Commits reward block + state updates

---

## Safety guardrails (current)

- Rejects tiny PR contributions in scoring (`<10` changed lines)
- Excludes configured bot accounts from rewards
- Penalizes self-merge in scoring
- Caps scored PRs per user per day
- Caps max score per user per day
- Mint-time checks:
  - reject if total distributed > daily emission
  - reject if any user reward > `maxRewardPerUser`
  - optional weekday abort when merged PR count is zero

Config: `config/reward-repos.json`

---

## Local usage

### CLI helper

```bash
node scripts/sequin_cli.js wallet:create --github <your-github-username>
node scripts/sequin_cli.js tx:next-nonce --user <you>
node scripts/sequin_cli.js tx:sign --from <you> --to <them> --amount 10 --nonce 1 --memo "hello"
```

- Public wallet file: `wallets/<username>.json`
- Private key path: `.sequin/keys/<username>.key` (gitignored)

### Validation scripts

```bash
node scripts/verify_chain.js
node scripts/verify_tx.js
node scripts/score_epoch.js --date YYYY-MM-DD
node scripts/mint_rewards.js --date YYYY-MM-DD
node scripts/ledger_summary.js --top 10 --epochs 7
```

---

## Notes

- This is intentionally a novelty/experimental chain model.
- Consensus is governance + branch protection + required checks.
- If you enable merge queue and strict required checks, you reduce nonce race/collision risk.
- Nonce collision policy: if two tx PRs race for the same sender nonce, the later one should rebase, regenerate with the next nonce, and rerun checks.
- Reward scoring epoch uses UTC calendar days (`00:00:00Z` to `23:59:59Z`).

---

## Related docs

- `GITHUB_NATIVE_SEQUIN_PLAN.md`
- `GITHUB_NATIVE_USAGE.md`
