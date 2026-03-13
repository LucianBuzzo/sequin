# GitHub-Native Sequin Usage (Draft)

## Register a wallet via PR

### Fast path (CLI helper)

```bash
node scripts/sequin_cli.js wallet:create --github <your-github-username>
```

This creates:
- public wallet file: `wallets/<username>.json` (commit this)
- private key: `.sequin/keys/<username>.key` (**never commit this**)

Then open a PR with the wallet file.

### Manual path

Create `wallets/<your-github-username>.json`:

```json
{
  "github": "your-username",
  "pubkey": "ed25519:BASE64_PUBKEY",
  "createdAt": "2026-03-13T12:00:00Z"
}
```

## Send sequins via PR

### Fast path (CLI helper)

```bash
node scripts/sequin_cli.js tx:sign --from <you> --to <them> --amount 10 --nonce 1 --memo "hello sequin"
```

This writes a signed tx file to `tx/pending/*.json`.

Open a PR containing that tx file.

### Manual tx format

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

## Validation and merge behavior

- `validate-tx` checks:
  - wallet filename ↔ github field match
  - registered sender/receiver wallets
  - nonce progression (`current + 1`)
  - sufficient sender balance
  - Ed25519 signature against canonical payload
- after merge, `rebuild-ledger` applies pending tx into a new block and updates balances/nonces.

## Canonical signed payload

The signature is over this exact JSON object (stringified with stable key order):

```json
{
  "id": "...",
  "from": "...",
  "to": "...",
  "amount": 1,
  "nonce": 1,
  "memo": "",
  "createdAt": "..."
}
```

(`signature` itself is excluded from signed payload.)

## Notes

- Reward PR generation is scaffolded in `nightly-rewards.yml` and still needs PoPR scoring implementation.
- This is V1 scaffold; branch protection + required checks should be enabled before broad use.
