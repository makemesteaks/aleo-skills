# Wallet Integration

## Overview

Aleo wallet adapters are provided by the [ProvableHQ/aleo-dev-toolkit](https://github.com/ProvableHQ/aleo-dev-toolkit) monorepo. All packages are under the `@provablehq` scope on npm. The recommended wallet is **Shield Wallet**.

**Note:** The package name uses "adaptor" (British spelling), not "adapter".

## Packages

| Package | Purpose |
|---------|---------|
| `@provablehq/aleo-wallet-adaptor-core` | Core logic, `DecryptPermission`, error types |
| `@provablehq/aleo-wallet-adaptor-react` | React context provider (`AleoWalletProvider`) and `useWallet` hook |
| `@provablehq/aleo-wallet-adaptor-react-ui` | Pre-built UI components (`WalletMultiButton`, `WalletModalProvider`) |
| `@provablehq/aleo-wallet-adaptor-shield` | Shield Wallet adapter |
| `@provablehq/aleo-types` | Shared types: `Network` enum, `TransactionStatus` |
| `@provablehq/sdk` | Aleo SDK (ProgramManager, AleoNetworkClient, Account) |

Other adapters: `@provablehq/aleo-wallet-adaptor-leo`, `@provablehq/aleo-wallet-adaptor-puzzle`, `@provablehq/aleo-wallet-adaptor-fox`, `@provablehq/aleo-wallet-adaptor-soter`.

## Installation

All wallet adaptor packages are currently at version `0.3.0-alpha.3` on npm.

```bash
npm install @provablehq/aleo-wallet-adaptor-core@0.3.0-alpha.3 \
            @provablehq/aleo-wallet-adaptor-react@0.3.0-alpha.3 \
            @provablehq/aleo-wallet-adaptor-react-ui@0.3.0-alpha.3 \
            @provablehq/aleo-wallet-adaptor-shield@0.3.0-alpha.3 \
            @provablehq/aleo-types \
            @provablehq/sdk
```

**Important:** Use React 18. The wallet adapter packages require React 18 peer dependencies. The `^0.0.1` semver range will NOT match these alpha versions — pin exact versions.

## Provider Setup

```jsx
import { useMemo } from 'react';
import { AleoWalletProvider } from '@provablehq/aleo-wallet-adaptor-react';
import { WalletModalProvider } from '@provablehq/aleo-wallet-adaptor-react-ui';
import { ShieldWalletAdapter } from '@provablehq/aleo-wallet-adaptor-shield';
import { DecryptPermission } from '@provablehq/aleo-wallet-adaptor-core';
import { Network } from '@provablehq/aleo-types';

import '@provablehq/aleo-wallet-adaptor-react-ui/dist/styles.css';

export default function WalletWrapper({ children }) {
    const wallets = useMemo(() => [new ShieldWalletAdapter()], []);

    return (
        <AleoWalletProvider
            wallets={wallets}
            decryptPermission={DecryptPermission.UponRequest}
            network={Network.TESTNET}
            programs={['my_program.aleo']}
            onError={(error) => console.error('[Wallet]', error)}
        >
            <WalletModalProvider>{children}</WalletModalProvider>
        </AleoWalletProvider>
    );
}
```

## Enum Values

| Enum | Key | String Value |
|------|-----|-------------|
| `DecryptPermission.NoDecrypt` | `NoDecrypt` | `"NO_DECRYPT"` |
| `DecryptPermission.UponRequest` | `UponRequest` | `"DECRYPT_UPON_REQUEST"` |
| `DecryptPermission.AutoDecrypt` | `AutoDecrypt` | `"AUTO_DECRYPT"` |
| `DecryptPermission.OnChainHistory` | `OnChainHistory` | `"ON_CHAIN_HISTORY"` |
| `Network.MAINNET` | `MAINNET` | `"mainnet"` |
| `Network.TESTNET` | `TESTNET` | `"testnet"` |
| `Network.CANARY` | `CANARY` | `"canary"` |

## Using the Wallet Hook

```jsx
import { useWallet } from '@provablehq/aleo-wallet-adaptor-react';
import { WalletMultiButton } from '@provablehq/aleo-wallet-adaptor-react-ui';

function MyComponent() {
    const { publicKey, connected, wallet } = useWallet();

    if (!connected) return <WalletMultiButton />;
    return <div>Connected: {publicKey}</div>;
}
```

## Executing Transactions

Use `executeTransaction` and `transactionStatus` from `useWallet()` directly (not `wallet.adapter`).

```jsx
const {
    connected,
    executeTransaction,
    transactionStatus: getTransactionStatus,
} = useWallet();

const executeOnChain = async () => {
    if (!connected) throw new Error('Wallet not connected');

    // TransactionOptions: { program, function, inputs, fee }
    const tx = await executeTransaction({
        program: 'my_program.aleo',
        function: 'my_function',
        inputs: ['1u8', '2u64'],
        fee: 300_000, // microcredits
    });
    // tx = { transactionId: string } — temp tracking ID from wallet

    // Poll for acceptance (2s interval — testnet block time is ~5s)
    // getTransactionStatus() returns { status, transactionId?, error? }
    // IMPORTANT: Shield wallet returns PascalCase status values:
    //   "Pending" | "Accepted" | "Failed" | "Rejected"
    // Always normalize with .toLowerCase() before comparing.
    // The tracking ID (shield_...) transitions through:
    //   1. { status: "Pending" }  — proving in progress
    //   2. { status: "Pending", transactionId: "at1..." }  — proved, broadcasting
    //   3. { status: "Accepted", transactionId: "at1..." }  — confirmed on-chain
    const interval = setInterval(async () => {
        const result = await getTransactionStatus(tx.transactionId);
        const status = result.status?.toLowerCase();
        // result.transactionId = on-chain TX ID (once submitted)
        if (status === 'accepted') {
            clearInterval(interval);
            console.log('On-chain TX:', result.transactionId);
        }
        if (status === 'failed' || status === 'rejected') {
            clearInterval(interval);
            console.error('Failed:', result.error);
        }
    }, 2000);
};
```

## Reading Public Transaction Outputs
<!-- Verified: 2026-03-15 — architectural, not version-specific -->

The wallet adapter does NOT return transaction outputs — `executeTransaction` returns only `{ transactionId }` and `transactionStatus` returns only status/error. This is architectural (confirmed from source), not a missing feature.

To read public outputs from a completed transaction, query the Aleo REST API directly:

```jsx
// After transaction is "Accepted" and you have the on-chain transactionId (at1...)
const res = await fetch(
    `https://api.explorer.provable.com/v1/testnet/transaction/${onChainTxId}`
);
const tx = await res.json();
// Navigate: tx.execution.transitions[].outputs[]
// Public outputs have type: "public", value is a bare string (e.g., "true", "42u64")
```

**Key gotcha:** The `transactionId` from `executeTransaction()` is a temporary tracking ID (`shield_...`). The on-chain transaction ID (`at1...`) only appears in `transactionStatus()` results after the transaction is accepted. Use the `at1...` ID for API queries.

## Fetching Records
<!-- Verified: v0.3.0-alpha.3, 2026-03-15 -->

`requestRecords(programId, includePlaintext?)` returns an array of record objects from the wallet. Each record has the following shape (Shield wallet v0.3.0-alpha.3):

```json
{
  "blockHeight": 15088185,
  "blockTimestamp": 1773568978,
  "commitment": "...field",
  "functionName": "commit_secret",
  "outputIndex": 0,
  "owner": "...field",
  "programName": "zk_guessing_game.aleo",
  "recordCiphertext": "record1qvqs...",
  "recordName": "Secret",
  "sender": "aleo1...",
  "spent": false,
  "tag": "...field",
  "transactionId": "at1...",
  "transitionId": "au1...",
  "transactionIndex": 0,
  "transitionIndex": 0
}
```

**Key notes:**
- Records have `recordCiphertext`, NOT a `plaintext` field (even with `includePlaintext: true`)
- **You MUST decrypt before passing as input**: call `wallet.decrypt(record.recordCiphertext)` to get the plaintext string, then pass that to `executeTransaction` inputs. Passing ciphertext directly fails with "Failed to parse input".
- Filter unspent records with `!record.spent`
- No `data` property — field values are not exposed in the record object
- `owner` is a field element (not an address) — it's the encrypted owner
- <!-- Verified: v0.3.0-alpha.3, 2026-03-15 — may improve in future wallet versions --> **Record indexing lags transaction confirmation**: after `transactionStatus()` returns "Accepted", `requestRecords()` may still return stale data. The wallet needs time to scan and index the new block. Poll `requestRecords()` until the expected record appears — do not assume record availability is synchronous with transaction confirmation. Use record metadata fields (`functionName`, `commitment`, `blockHeight`) to detect when a new record has appeared without triggering unnecessary `decrypt()` calls.

```jsx
const { decrypt, requestRecords, executeTransaction } = useWallet();

const records = await requestRecords('my_program.aleo', true);
const unspent = records.filter((r) => !r.spent && r.recordName === 'Token');

// Decrypt the record ciphertext to get plaintext for the prover
const plaintext = await decrypt(unspent[0].recordCiphertext);
// plaintext is an Aleo record string like "{owner: aleo1..., amount: 100u64, _nonce: ...group}"

await executeTransaction({
    program: 'my_program.aleo',
    function: 'transfer',
    inputs: [plaintext, 'aleo1receiver...', '50u64'],
    fee: 300_000,
    privateFee: false,
});
```

## Querying Mappings

```jsx
import { AleoNetworkClient } from '@provablehq/sdk';

const networkClient = new AleoNetworkClient('https://api.explorer.provable.com/v1');

const value = await networkClient.getProgramMappingValue(
    'my_program.aleo',
    'balances',
    'aleo1...'
);
// Returns string like "100u64" — parse with parseInt(value.replace("u64", ""))
```

## Reference Implementation

The official Provable dev toolkit demonstrates the complete pattern:
`ProvableHQ/aleo-dev-toolkit` on GitHub — see `examples/react-app/`.
