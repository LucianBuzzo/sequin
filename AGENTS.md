# AGENTS.md — Sequin Field Notes

> prisma/prisma-style: short, practical, no fluff.

## Mission

Sequin is a **GitHub-backed novelty currency**.

- Ledger = repo state
- Transactions = PRs
- Validation + mint = GitHub Actions
- Tooling/runtime = **Crystal** (target state)

No always-on server.

---

## Hard Rules

1. **GitHub-backed only**
   - Do not reintroduce long-running node/server consensus paths.
   - `master` is canonical chain state.

2. **Crystal-first implementation**
   - New core logic goes in Crystal.
   - JS/Node is temporary migration scaffolding only.

3. **Deterministic state transitions**
   - Same inputs must produce same outputs.
   - Avoid non-deterministic ordering and implicit time dependencies.

4. **Conventional Commits required**
   - Examples: `feat: ...`, `fix: ...`, `chore: ...`, `docs: ...`, `refactor: ...`
   - Keep commit subject imperative + scoped when useful.

5. **Branch protection respected**
   - Required checks must pass before merge.
   - If nonce races occur, rebase + regenerate tx nonce.

---

## Preferred Working Style

- Small, reviewable PRs.
- One concern per PR.
- Include a short “why” in PR body.
- Include exact verification steps and output.

### Suggested PR sizing

- PR 1: Toolchain upgrades only
- PR 2: Crystal CLI skeleton + shared IO helpers
- PR 3+: One migrated command family per PR

---

## Source of Truth (Current)

- `ledger/` → chain + state
- `wallets/` → registered public keys
- `tx/pending/` → signed transfer intents
- `rewards/` → epoch reward manifests
- `.github/workflows/` → execution pipeline

---

## Safety + Integrity Notes

- Private keys stay local; never commit secrets.
- Validate signatures, nonces, balances before state mutation.
- Keep anti-gaming guardrails enabled for rewards.
- Fail closed on malformed data.

---

## Testing Expectations

For any behavioral change:

- Add/adjust tests
- Run targeted tests locally
- Run relevant workflow logic locally where possible
- Paste command + result in PR

---

## Migration Direction (Explicit)

- Remove legacy Crystal server/miner path.
- Keep project in Crystal by replacing JS scripts with Crystal CLI commands.
- Remove Node from required CI/runtime path once parity is reached.
