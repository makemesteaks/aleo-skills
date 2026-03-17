# Aleo + Leo Development

This repo uses the `aleo-skills` skill for end-to-end Aleo blockchain development.

## Invoke the Skill BEFORE Writing Code

Always invoke `aleo-skills` first for ANY Aleo/Leo task — it contains correct patterns for
Leo programs, the @provablehq/sdk, wallet integration, ZK proofs, and deployment.

## Key Reminders

- Private state → `record` (UTXO, consumed on use, off-chain)
- Public state → `mapping` (on-chain via `finalize`, publicly visible)
- All loops require compile-time-known bounds (ZK constraint requirement)
- SDK imports must be network-specific: `@provablehq/sdk/testnet.js` or `/mainnet.js`
- Browser: all SDK calls must run in a Web Worker — never the main thread
- Deployment: `leo deploy --broadcast` to actually deploy (without flag = dry run only)
- Programs require a `constructor` (ConsensusVersion::V9+)
- Block explorer: always use https://explorer.provable.com/
