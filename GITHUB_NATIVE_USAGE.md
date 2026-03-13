# GitHub-Native Sequin Usage (Draft)

## Register a wallet via PR

1. Generate an Ed25519 keypair locally (private key never leaves your machine).
2. Create `wallets/<your-github-username>.json`:

```json
{
  "github": "your-username",
  "pubkey": "ed25519:BASE64_PUBKEY",
  "createdAt": "2026-03-13T12:00:00Z"
}
```

3. Open a PR with that file.
4. `validate-tx` must pass.
5. Merge PR to register wallet.

## Send sequins via PR

1. Build a signed tx JSON in `tx/pending/`:

```json
{
  "id": "tx-001",
  "from": "your-username",
  "to": "recipient-username",
  "amount": 10,
  "nonce": 1,
  "memo": "hello sequin",
  "createdAt": "2026-03-13T12:05:00Z",
  "signature": "BASE64_SIG"
}
```

2. Open PR with tx file.
3. `validate-tx` checks nonce/balance/wallet + basic tx invariants.
4. After merge, `rebuild-ledger` applies tx into a new block and updates balances/nonces.

## Notes

- Signature crypto verification is currently TODO in scaffold (`scripts/verify_tx.js`).
- Reward PR generation is scaffolded in `nightly-rewards.yml` and still needs PoPR scoring implementation.
