# SIP-0002: Federated Consensus and Fork Discovery for Decentralized Sequin

- **SIP**: SIP-0002
- **Title**: Federated Consensus and Fork Discovery for Decentralized Sequin
- **Author**: Gravious (@gravious), Lucian Buzzo (@LucianBuzzo)
- **Discussions-To**: https://github.com/LucianBuzzo/sequin/discussions
- **Status**: Draft
- **Type**: Standards Track
- **Category**: Core
- **Created**: 2026-03-16
- **Requires**: SIP-0001
- **Replaces**: (none)
- **Superseded-By**: (none)

---

## Abstract

This SIP proposes a path to decentralize Sequin using a federated validator model where each repository fork can operate as a node. GitHub forks are used for node discovery, while consensus/finality is achieved by threshold validator attestations over proposed blocks. It introduces node identity metadata, attestation objects, a fork-choice/finality rule, and a claims-based issuance model for OSS pull-request rewards.

## Motivation

Current Sequin operation is deterministic but effectively centralized around one canonical repository and its CI workflow. We want:

- multiple independent operators (forks) to participate in validation
- no single actor as sole issuer/minter
- explicit finality that survives branch-level races
- a credible path from “GitHub-native experiment” to decentralized governance

Using GitHub forks as bootstrap discovery lowers operational friction while still allowing protocol-level decentralization.

## Specification

### 1) Node identity and discovery

Each participating fork MUST include `node/node.json`:

```json
{
  "nodeId": "sequin-node-<unique>",
  "owner": "github-login",
  "signingPubKey": "secp256k1:<compressed-pubkey-hex>",
  "protocolVersion": 1,
  "network": "sequin-mainnet",
  "endpoints": {
    "api": "https://example.com/sequin",
    "relay": "https://example.com/relay"
  },
  "updatedAt": "2026-03-16T00:00:00Z"
}
```

Bootstrap discovery:

1. query GitHub forks of canonical Sequin repo
2. fetch `node/node.json` from each fork default branch
3. validate schema + key format + network/protocol compatibility
4. construct active peer table

### 2) Validator set (federated)

A network config file (`network/validators.json`) defines the active validator set:

```json
{
  "epoch": 1,
  "validators": [
    {"nodeId": "sequin-node-a", "pubKey": "secp256k1:..."},
    {"nodeId": "sequin-node-b", "pubKey": "secp256k1:..."}
  ],
  "quorum": {
    "type": "threshold",
    "numerator": 2,
    "denominator": 3
  }
}
```

Finality threshold is M-of-N signatures, parameterized by `quorum`.

### 3) Block lifecycle

States:

1. **Proposed**: proposer publishes candidate block with deterministic state transition output.
2. **Attested**: validators publish attestations for `(height, blockHash)`.
3. **Finalized**: attestations reach quorum threshold.

Nodes MUST only treat finalized blocks as irreversible balance state.

### 4) Attestation format

Attestations live under `attestations/<height>/<blockHash>/<nodeId>.json`:

```json
{
  "height": 42,
  "blockHash": "<sha256>",
  "nodeId": "sequin-node-a",
  "timestamp": "2026-03-16T00:00:00Z",
  "signature": "secp256k1:<r_hex>:<s_hex>"
}
```

Signature payload is canonical JSON over: `height`, `blockHash`, `nodeId`, `timestamp`.

### 5) Fork-choice rule

Nodes SHOULD follow:

1. chain with highest finalized height
2. if tie, chain with greatest attestation weight at tip
3. if tie, lexicographically smallest tip hash (deterministic tiebreak)

### 6) Reward issuance as claims

Nightly auto-minting SHOULD be replaced by claims-based issuance:

- users submit `claim` transactions referencing merged PR evidence
- validators verify claim eligibility deterministically
- mint occurs only through finalized block inclusion

`claim` tx fields (draft):

```json
{
  "id": "claim-...",
  "type": "claim",
  "claimant": "github-login",
  "repo": "owner/repo",
  "prNumber": 123,
  "mergeCommit": "<sha>",
  "epoch": "YYYY-MM-DD",
  "nonce": 1,
  "sigVersion": 1,
  "signature": "secp256k1:<r_hex>:<s_hex>"
}
```

Protocol MUST enforce uniqueness over `(repo, prNumber, epoch)` and/or `claimId` to prevent double-mint.

### 7) Deterministic verification requirements

For every claim, validators MUST deterministically check:

- PR is merged in declared epoch window (UTC)
- claimant matches allowed attribution rule (initially PR author)
- claim not previously consumed
- reward amount from deterministic scoring parameters

### 8) State additions

Suggested additional state files:

- `ledger/state/finality.json`
- `ledger/state/validators.json`
- `ledger/state/claims_consumed.json`

## Rationale

Federated consensus is chosen as an incremental decentralization step:

- simpler to reason about than open Sybil-resistant consensus
- supports identifiable operators and governance iteration
- allows measured rollout while preserving deterministic execution

Fork-based discovery leverages GitHub-native strengths while avoiding bespoke node registries.

## Backwards Compatibility

This is a breaking architectural extension if enforced immediately. Recommended migration:

1. run federated attestations in shadow mode
2. compare outcomes with current canonical flow
3. switch finality gating once stable
4. deprecate centralized nightly auto-mint in favor of claims

## Security Considerations

Primary risks and mitigations:

- **Sybil forks**: only validator-listed forks count toward quorum
- **Attestation spam**: accept attestations only from active validator keys
- **Replay attacks**: signatures bind height+hash+nodeId+timestamp
- **GitHub API inconsistency**: use bounded epoch windows and recorded evidence in claim payload
- **Centralized infra dependence**: allow optional non-GitHub relay endpoints over time

## Testing

Minimum acceptance tests:

- node discovery across forks with mixed valid/invalid `node.json`
- attestation verification and threshold finalization
- fork-choice determinism under ties
- claim uniqueness and double-claim rejection
- claim verification for valid/invalid PR evidence
- shadow-mode parity against current single-chain path

## Reference Implementation (optional)

Planned follow-up work:

- add schemas: `schemas/node.schema.json`, `schemas/attestation.schema.json`, `schemas/claim.schema.json`
- add commands:
  - `node:discover`
  - `consensus:attest`
  - `consensus:finalize`
  - `rewards:verify-claim`
  - `rewards:apply-claim`

## Rollout Plan

Phase A — Discovery + identity
- introduce `node/node.json` and discovery tooling

Phase B — Attestation shadow mode
- collect signatures for proposed blocks, do not gate state yet

Phase C — Finality enforcement
- require quorum attestations before state is considered finalized

Phase D — Claims issuance
- switch from nightly auto-mint to claim transactions + validator verification

## Copyright

This document is licensed under CC0-1.0.
