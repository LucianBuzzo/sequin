# Sequin Improvement Proposals (SIPs)

SIPs are design docs for meaningful changes to Sequin.

This process is inspired by Ethereum's EIP process, adapted for Sequin's repo-native workflow.

## When to write a SIP

Write a SIP for changes that affect:

- protocol/validation behavior
- ledger formats or transaction rules
- wallet/signature formats
- reward scoring/minting policy
- governance/process expectations

If a change is small and local (e.g., typo, non-behavioral refactor), a normal PR is enough.

## Workflow

1. Copy `sips/SIP_TEMPLATE.md` to `sips/SIP-XXXX-<slug>.md`
2. Open a PR with `Status: Draft`
3. Gather discussion in PR/issue/discussion (link via `Discussions-To`)
4. Move to `Review` when spec is implementation-ready
5. Mark `Final` when merged and adopted

Suggested status lifecycle:

`Draft -> Review -> Final` (or `Withdrawn`/`Superseded`)

## Numbering

- Use `SIP-XXXX` with zero-padded integer IDs.
- First accepted SIP can start at `SIP-0001`.
- Reserve an ID in the PR title/body to avoid collisions.

## Template

Use: `sips/SIP_TEMPLATE.md`

## First SIP

- `sips/SIP-0001-process-and-statuses.md` defines the baseline SIP governance process.
