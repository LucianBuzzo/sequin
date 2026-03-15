# SIP-0001: Sequin Improvement Proposal Process and Statuses

- **SIP**: SIP-0001
- **Title**: Sequin Improvement Proposal Process and Statuses
- **Author**: Gravious (@gravious)
- **Discussions-To**: https://github.com/LucianBuzzo/sequin/pull/43
- **Status**: Final
- **Type**: Meta
- **Category**: Governance
- **Created**: 2026-03-15
- **Requires**: (none)
- **Replaces**: (none)
- **Superseded-By**: (none)

---

## Abstract

This SIP defines the baseline SIP process for Sequin: when a SIP is required, how SIPs are numbered, which statuses they move through, and what minimum fields every SIP must contain. The process is inspired by Ethereum's EIP process but intentionally simplified for Sequin's size and repo-native workflow.

## Motivation

Sequin now has protocol-critical behavior (transaction validation, signing formats, ledger/state transitions, and reward minting policies). Without a lightweight governance document process, these decisions can become fragmented across PR comments and ad hoc docs, making future maintenance harder.

A SIP process creates a stable, searchable design history and raises the quality bar for high-impact changes.

## Specification

### 1. SIP required changes

A SIP SHOULD be used for changes affecting:

- protocol/validation behavior
- ledger or tx data formats
- wallet/signature formats
- reward scoring or minting policy
- governance/process rules

Small local changes (typos, isolated refactors with no behavior impact) MAY proceed without a SIP.

### 2. File location and format

- SIPs live under `sips/`
- Naming convention: `sips/SIP-XXXX-<slug>.md`
- SIPs MUST use the canonical template from `sips/SIP_TEMPLATE.md`

### 3. Numbering

- IDs are zero-padded integers: `SIP-0001`, `SIP-0002`, ...
- New SIPs reserve an ID in their opening PR to avoid collisions.

### 4. Status lifecycle

Canonical statuses:

- `Draft`: initial proposal and active iteration
- `Review`: implementation-ready and seeking maintainers' decision
- `Final`: accepted and merged/adopted
- `Withdrawn`: intentionally abandoned
- `Superseded`: replaced by a newer SIP

### 5. Process

1. Copy `sips/SIP_TEMPLATE.md` to a numbered SIP file.
2. Open PR with `Status: Draft`.
3. Discuss in linked PR/issue/discussion via `Discussions-To`.
4. Move to `Review` when spec is implementation-ready.
5. Move to `Final` once accepted and merged.

## Rationale

This process chooses a minimal lifecycle over a complex standards taxonomy. Sequin benefits more from consistency and low-friction participation than from heavyweight ceremony.

## Backwards Compatibility

This is a governance/process SIP and introduces no runtime behavior changes.

## Security Considerations

A formal SIP process helps surface security concerns earlier by requiring explicit security sections for high-impact changes.

## Testing

No runtime tests required. Conformance is process-based and validated by:

- SIP file presence and format
- template usage
- linked discussion and status transitions

## Reference Implementation (optional)

- `sips/README.md`
- `sips/SIP_TEMPLATE.md`
- `sips/SIP-0001-process-and-statuses.md`

## Rollout Plan

- Adopt this SIP immediately as baseline governance.
- Require SIP linkage in PRs that touch protocol/validation/rewards/crypto.

## Copyright

This document is licensed under CC0-1.0.
