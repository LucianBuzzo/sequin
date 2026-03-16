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

## Canonical model

Sequin operates as a GitHub-native ledger:

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
src/sequin_tool/
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
- PR-level idempotency:
  - rewarded PR identities are tracked in `ledger/state/rewarded_prs.json`
  - rerunning mint for the same day only mints new, previously unseen PR claims

Config: `config/reward-repos.json`

### Add a new repository for rewards

To include another OSS repo in reward scoring:

1. Edit `config/reward-repos.json`
2. Add the repo to `repos` using `owner/name` format
3. Open a PR and merge after checks pass
4. Trigger nightly rewards naturally (or run `workflow_dispatch`) and verify the next epoch manifest includes activity from the new repo

Example:

```json
{
  "repos": [
    "LucianBuzzo/sequin",
    "owner/another-repo"
  ]
}
```

Notes:

- The workflow token must be able to read the target repo's PR metadata.
- Keep repos public (or ensure token access), otherwise scoring may fail.
- Add noisy bot accounts to `excludeLogins` when needed.

---

## Local usage

Crystal-based commands and specs are currently verified against Crystal `1.13.2`.

### CLI helper

```bash
crystal run src/sequin_tool.cr -- wallet:create --github <your-github-username>
crystal run src/sequin_tool.cr -- tx:next-nonce --user <you>
crystal run src/sequin_tool.cr -- tx:sign --from <you> --to <them> --amount 10 --nonce 1 --memo "hello"
```

- Public wallet file: `wallets/<username>.json`
- Private key path: `.sequin/keys/<username>.key` (gitignored)

### Validation commands

```bash
crystal run src/sequin_tool.cr -- verify:chain
crystal run src/sequin_tool.cr -- verify:tx
crystal run src/sequin_tool.cr -- rewards:score-epoch --date YYYY-MM-DD
crystal run src/sequin_tool.cr -- rewards:mint --date YYYY-MM-DD
crystal run src/sequin_tool.cr -- ledger:summary --top 10 --epochs 7
crystal run src/sequin_tool.cr -- repo:lint
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

- `MIGRATION_TODO.md` (Crystal migration execution checklist)
- `AGENTS.md` (project field notes + guardrails)
- `GITHUB_NATIVE_SEQUIN_PLAN.md`
- `GITHUB_NATIVE_USAGE.md`
- `sips/README.md` + `sips/SIP_TEMPLATE.md` (Sequin Improvement Proposal process/template)
