# Sequin Migration TODO — Crystal + GitHub-Backed

> Field notes format. Checklist is execution order.

## Definition of Done

- [x] No Node runtime required for core CI/workflows
- [ ] GitHub-backed ledger flow fully handled by Crystal tooling
- [x] Legacy server/miner path removed
- [ ] Docs reflect one canonical architecture

---

## Phase 0 — Foundations

### 0.1 Decide crypto path (blocking)
- [ ] Choose and record signature standard:
  - [ ] Keep Ed25519 (preferred for compatibility)
  - [ ] OR migrate to secp256k1 (breaking format change)

**Acceptance:** decision documented in README + this file.

### 0.2 Baseline branch protections
- [ ] Confirm required checks on `master`
- [ ] Confirm up-to-date branch requirement
- [ ] Enable merge queue (recommended)

**Acceptance:** screenshot or CLI output linked in PR.

---

## Phase 1 — Crystal Toolchain Upgrade

### 1.1 Runtime/tooling modernization
- [x] Upgrade Crystal version from `0.35.1` to current stable target
- [x] Update `shard.yml` and dependency constraints
- [x] Verify `shards install` + test suite locally

**Acceptance:** CI `unit` green on upgrade PR.

### 1.2 Dependency hygiene
- [x] Mark `kemal` + `crest` as legacy (temporary)
- [ ] Add required deps for:
  - [ ] crypto path
  - [ ] HTTP/GitHub API client robustness
  - [ ] CLI ergonomics (if needed)

**Acceptance:** dependency rationale in PR notes.

---

## Phase 2 — Unified Crystal CLI Skeleton

Create `sequin_tool` (single entrypoint, subcommands).

- [x] Add command router and shared helpers:
  - [x] JSON read/write
  - [x] canonical serialization
  - [x] fs safety helpers
  - [x] structured error output

Subcommands (empty or stubbed initially):
- [x] `verify:chain`
- [x] `verify:tx`
- [x] `ledger:apply-block`
- [x] `rewards:score-epoch`
- [x] `rewards:mint`
- [x] `ledger:summary`
- [x] `wallet:create`
- [x] `tx:next-nonce`
- [x] `tx:sign`
- [x] `repo:lint`

**Acceptance:** binary runs and each command returns a clear status.

---

## Phase 3 — Port Deterministic Ledger Operations (Low Risk)

### 3.1 Chain verification
- [x] Port `scripts/verify_chain.js` → Crystal `verify:chain`

### 3.2 Apply block
- [x] Port `scripts/apply_block.js` → Crystal `ledger:apply-block`

### 3.3 Mint rewards
- [x] Port `scripts/mint_rewards.js` → Crystal `rewards:mint`

### 3.4 Summary/reporting
- [x] Port `scripts/ledger_summary.js` → Crystal `ledger:summary`

**Acceptance:** parity tests pass against existing fixture data.

---

## Phase 4 — Port GitHub Epoch Scoring (Medium Risk)

### 4.1 Score engine
- [x] Port `scripts/score_epoch.js` → Crystal `rewards:score-epoch`
- [x] Keep scoring constants/config in `config/reward-repos.json`

### 4.2 Hardening
- [x] Implement pagination for GitHub API responses
- [x] Add retry/backoff for transient API failures
- [x] Add clear failure messaging for missing token/rate-limit

**Acceptance:** output manifest matches expected structure + deterministic test snapshot.

---

## Phase 5 — Port Crypto + TX Tooling (High Risk)

### 5.1 Wallet + tx CLI
- [x] Port `scripts/sequin_cli.js` wallet commands:
  - [x] `wallet:create`
  - [x] `tx:next-nonce`
  - [x] `tx:sign`

### 5.2 Tx verifier
- [x] Port `scripts/verify_tx.js` to Crystal `verify:tx`
- [x] Preserve canonical payload/signature rules
- [x] Preserve nonce/balance simulation semantics

### 5.3 Compatibility checks
- [ ] Add cross-check tests during migration:
  - [ ] Crystal validates legacy JS-generated tx fixtures
  - [ ] (If temporarily needed) JS validates Crystal-generated fixtures

**Acceptance:** signature and nonce validation parity demonstrated in CI.

---

## Phase 6 — Workflow Cutover (Node → Crystal)

### 6.1 Validate tx workflow
- [x] Replace Node steps with Crystal command invocations in `validate-tx.yml`

### 6.2 Rebuild ledger workflow
- [x] Replace Node steps with Crystal command invocations in `rebuild-ledger.yml`

### 6.3 Nightly rewards workflow
- [x] Replace Node steps with Crystal command invocations in `nightly-rewards.yml`

### 6.4 CI ergonomics
- [x] Add build/cache strategy for Crystal binary to keep workflow duration sane *(shards cache enabled; binary build caching can be layered later)*

**Status note:** validate/rebuild/nightly now run via Crystal `sequin_tool` commands; Node bridge removed from core workflow paths.

**Acceptance:** all three workflows green without `setup-node`.

---

## Phase 7 — Remove Legacy Paths

### 7.1 Remove server/miner model
- [x] Delete legacy server entrypoints and peer/mining runtime
- [x] Remove related deps/config/docs

### 7.2 Remove JS scaffolding
- [ ] Delete migrated JS scripts
- [ ] Remove JS-specific lint checks

### 7.3 Docs cleanup
- [ ] Update README to single canonical architecture
- [ ] Add migration notes/changelog entries

**Acceptance:** repo has one runtime model (Crystal + GitHub-backed workflows).

---

## Phase 8 — Final Verification Gate

Run end-to-end in dry run and real flow:

- [ ] Wallet registration PR
- [ ] Transfer tx PR + block apply
- [ ] Nightly score + mint epoch
- [ ] Ledger verify + summary outputs

**Acceptance:** full lifecycle works with Crystal-only command path.

---

## PR Plan (Recommended)

- [x] PR-1: Toolchain upgrade + AGENTS/MIGRATION docs
- [x] PR-2: `sequin_tool` skeleton + shared libs
- [x] PR-3: deterministic ledger ops port
- [x] PR-4: epoch scoring port + hardening
- [x] PR-5: crypto + tx tooling port
- [x] PR-6: workflow cutover
- [ ] PR-7: remove legacy server + JS scripts
- [ ] PR-8: final cleanup/docs + release

---

## Commit Convention

Use Conventional Commits throughout.

Examples:
- `chore(crystal): upgrade toolchain and shard constraints`
- `feat(cli): add verify-chain and apply-block commands`
- `feat(rewards): port epoch scoring to crystal`
- `refactor(workflows): switch nightly rewards to crystal binary`
- `chore(legacy): remove kemal server runtime`
