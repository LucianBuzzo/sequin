# GitHub-Native Sequin (No Server) Plan

## Vision
Turn Sequin into a novelty cryptocurrency where GitHub is the execution environment:

- Ledger state is stored in the repository
- Transactions are submitted via Pull Requests
- GitHub Actions validates and applies state changes
- Rewards are minted from GitHub contribution activity (Proof of Pull Request)

Main branch is the canonical chain.

---

## Architecture (V1)

### Repository-as-ledger
- `ledger/blocks/*.json` append-only block records
- `ledger/state/balances.json` account balances by GitHub username
- `ledger/state/nonces.json` monotonic nonce per sender
- `wallets/<github-user>.json` registered public keys
- `tx/pending/*.json` signed transfer intents submitted in PRs
- `rewards/YYYY-MM-DD.json` generated reward transactions

### Trust and consensus
- Consensus is branch protection + required checks + code review
- No daemon, no network peers, no always-on server
- GitHub Actions is the deterministic validator/executor

### Wallets
- Client-side keypairs only (private key never leaves user machine)
- Wallet registration via PR adding `wallets/<username>.json`

### Transaction lifecycle
1. User creates/signs tx locally
2. User opens PR adding `tx/pending/*.json`
3. Action validates schema/signature/nonce/balance
4. On merge, block/state update is applied

### Reward lifecycle
1. Nightly action scores merged PR activity
2. Action opens reward PR with `rewards/YYYY-MM-DD.json`
3. Merge applies coinbase rewards

---

## TODO Checklist

- [x] Clone `sequin` into `~/projects/sequin`
- [x] Create this plan file with architecture + roadmap
- [x] Scaffold repo directories/files for GitHub-native ledger model
- [x] Add JSON schemas for wallet, tx, and block formats
- [x] Add `validate-tx.yml` workflow (PR validation)
- [x] Add `nightly-rewards.yml` workflow (scheduled reward PR creation)
- [x] Add `rebuild-ledger.yml` workflow (apply state on merge)
- [x] Add deterministic validation/apply scripts under `scripts/`
- [x] Add docs for "wallet registration by PR"
- [x] Add docs for "send sequins via PR"
- [x] Run validation locally (schema + deterministic state rebuild)
- [x] Open PR with V1 scaffold
- [x] Replace nightly rewards placeholder with initial PoPR scoring script

## Progress notes

- Added real Ed25519 signature verification to `scripts/verify_tx.js` using canonical tx payload.
- Added local helper CLI `scripts/sequin_cli.js` for wallet creation and tx signing.
- Ran a local smoke cycle (wallet create -> sign tx -> verify -> apply block) and reset repo state back to clean genesis.

---

## Implementation Notes

### Determinism first
All action scripts should be deterministic and reject ambiguous states.

### Race handling
Require up-to-date branch and rerun checks to avoid nonce conflicts.

### Anti-abuse defaults
- minimum tx amount > 0
- unique tx IDs
- nonce must equal `current + 1`
- reject unknown senders

### Reward anti-gaming (V1)
- score from merged PRs only
- cap per-user daily reward score
- ignore bot accounts

---

## Immediate next steps
1. Scaffold directories and state seed files
2. Add schemas
3. Add basic validation script + workflow
4. Iterate until PR-ready
