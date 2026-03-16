# Frontend SDK Integration

## Overview

The Provable SDK (`@provablehq/sdk`) is a TypeScript/JavaScript library for building ZK web apps on Aleo. It handles:
- Account management (key generation, signing, encryption)
- Program execution (local + on-chain) with ZK proof generation via WASM
- Program deployment
- Credit transfers, joins, splits
- Network queries (blocks, transactions, mappings, programs)
- Staking operations (bond, unbond, claim)

**SDK v0.9.18** — wraps `@provablehq/wasm` (Rust/snarkVM compiled to WebAssembly).

## Installation

```bash
npm install @provablehq/sdk
```

## Critical: Network-Specific Imports

**Always import from the network-specific entry point**, never the bare package:

```typescript
// ✅ Correct — network-specific import
import { Account, AleoNetworkClient } from '@provablehq/sdk/testnet.js';
import { ProgramManager } from '@provablehq/sdk/mainnet.js';

// ❌ Wrong — bare import (may resolve incorrectly or pull wrong network)
import { Account } from '@provablehq/sdk';
```

The SDK builds separate bundles per network (`testnet`, `mainnet`, `dynamic`). Each has `browser.js` and `node.js` exports. The bare package may not resolve to the correct network variant.

## SDK Role: Browser vs Node

### Node.js
The SDK runs natively — no WASM worker setup needed. Use for:
- Backend servers building/submitting transactions
- CLI tools for account management and chain queries
- Local testing and prototyping
- Offline transaction building (hardware wallets)

### Browser
In browser contexts, the SDK **supplements** the wallet adapter — it does NOT replace it:

| Concern | Use wallet adapter | Use SDK directly |
|---------|-------------------|-----------------|
| Account connection | ✅ | |
| Transaction execution | ✅ | |
| Transaction status polling | ✅ | |
| Record scanning | ✅ | |
| Deployments | ✅ | |
| Cryptographic hashing | | ✅ |
| Program introspection | | ✅ |
| Arbitrary encryption/decryption | | ✅ |
| Reading public mappings | | ✅ |

**All `@provablehq/sdk` imports in browser must live in a Web Worker** — never in the main thread. Use Comlink to expose worker methods.

## Bundler Configuration

### Vite (official template pattern)
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [react()],
    // Treat .wasm files as assets (correct MIME type)
    assetsInclude: ['**/*.wasm'],
    optimizeDeps: {
        esbuildOptions: { target: 'esnext' },
        // Exclude the WASM package (not the SDK) from dep optimization
        exclude: ['@provablehq/wasm'],
    },
    server: {
        headers: {
            // Required for WASM + Web Worker cross-origin isolation
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
        },
    },
    build: { target: 'esnext' },
});
```

**Key points:**
- Exclude `@provablehq/wasm` (the WASM binary), NOT `@provablehq/sdk` (pure TS)
- `assetsInclude: ['**/*.wasm']` ensures correct MIME type serving
- COOP/COEP headers required for `SharedArrayBuffer` (used by WASM thread pool)

### Webpack
```javascript
module.exports = {
    experiments: {
        asyncWebAssembly: true,
        topLevelAwait: true,
    },
    resolve: { extensions: ['.js', '.wasm', '.jsx'] },
    devServer: {
        headers: {
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
        },
    },
};
```

## Quick Start with create-leo-app

```bash
npm create leo-app@latest
cd aleo-project
npm install
npm run install-leo
npm run dev
```

Templates in `create-leo-app/template-*/` cover Node.js and React patterns.

## Core Classes

### Account
```typescript
import { Account } from '@provablehq/sdk/testnet.js';

// Generate new account
const account = new Account();

// From existing private key
const account = new Account({ privateKey: 'APrivateKey1...' });

// Access keys
account.privateKey();   // APrivateKey1...
account.viewKey();      // AViewKey1...
account.address();      // aleo1...

// Sign and verify messages
const signature = account.sign(new TextEncoder().encode('hello'));
const valid = account.verify(new TextEncoder().encode('hello'), signature);

// Decrypt records (server-side or worker)
const plaintext = account.decryptRecord(ciphertextString);
const plaintexts = account.decryptRecords(ciphertextArray);

// Check record ownership
const owns = account.ownsRecordCiphertext(ciphertext);

// Encrypt account for storage
const encrypted = account.encryptAccount(password);
```

### AleoNetworkClient
```typescript
import { AleoNetworkClient } from '@provablehq/sdk/testnet.js';

const client = new AleoNetworkClient("https://api.explorer.provable.com/v1");

// --- Block queries ---
const block = await client.getBlock(1);
const blockByHash = await client.getBlockByHash("ab1...");
const range = await client.getBlockRange(1, 10);
const latestBlock = await client.getLatestBlock();
const latestHeight = await client.getLatestHeight();
const latestHash = await client.getLatestBlockHash();

// --- Program queries ---
const program = await client.getProgram("credits.aleo");
const programObj = await client.getProgramObject("credits.aleo");
const imports = await client.getProgramImports("my_dex.aleo");
const importNames = await client.getProgramImportNames("my_dex.aleo");
const mappingNames = await client.getProgramMappingNames("token.aleo");

// --- Mapping values ---
const value = await client.getProgramMappingValue("credits.aleo", "account", "aleo1...");
// Returns string like "100u64" — parse with parseInt(value.replace("u64", ""))

// --- Transaction queries ---
const tx = await client.getTransaction("at1...");
const confirmed = await client.getConfirmedTransaction("at1...");
const txObj = await client.getTransactionObject("at1...");
const blockTxs = await client.getTransactions(100);      // by block height
const hashTxs = await client.getTransactionsByBlockHash("ab1...");
const mempool = await client.getTransactionsInMempool();

// --- Deployment lookup ---
const deployTx = await client.getDeploymentTransactionForProgram("my_app.aleo");
const deployId = await client.getDeploymentTransactionIDForProgram("my_app.aleo");

// --- Balance ---
const balance = await client.getPublicBalance("aleo1...");

// --- Record discovery ---
const records = await client.findUnspentRecords(startHeight, endHeight, privateKey);

// --- Submit transaction ---
const txId = await client.submitTransaction(transactionObject);

// --- Transaction confirmation (built-in polling) ---
const confirmedTx = await client.waitForTransactionConfirmation(
    "at1...",
    2000,    // checkInterval ms (default: 2000)
    45000,   // timeout ms (default: 45000)
);
// Polls /transaction/confirmed/{id} internally.
// Stops on 4xx with "Invalid URL" (malformed ID).
// Returns ConfirmedTransactionJSON on success.
```

### ProgramManager (execute & deploy)
```typescript
import {
    Account, ProgramManager, AleoKeyProvider,
    AleoNetworkClient, NetworkRecordProvider, initThreadPool
} from '@provablehq/sdk/testnet.js';

// Initialize WASM thread pool (required, do once)
await initThreadPool();

// Setup providers
const account = new Account({ privateKey: 'APrivateKey1...' });
const keyProvider = new AleoKeyProvider();
keyProvider.useCache(true);
const networkClient = new AleoNetworkClient("https://api.explorer.provable.com/v1");
const recordProvider = new NetworkRecordProvider(account, networkClient);

const pm = new ProgramManager(
    "https://api.explorer.provable.com/v1",
    keyProvider,
    recordProvider
);
pm.setAccount(account);
```

### Execute a Program
```typescript
// On-chain execution (submits transaction, returns tx ID)
const txId = await pm.execute({
    programName: "hello_hello.aleo",
    functionName: "hello",
    inputs: ["5u32", "5u32"],
    fee: 0.2,
});

// Wait for confirmation
const confirmedTx = await networkClient.waitForTransactionConfirmation(txId);

// Build without submitting (inspect before broadcast)
const tx = await pm.buildExecutionTransaction({
    programName: "hello_hello.aleo",
    functionName: "hello",
    inputs: ["5u32", "5u32"],
    fee: 0.2,
});
// Then submit manually: await networkClient.submitTransaction(tx);
```

**When to use which polling approach:**
- **SDK direct execution** (`ProgramManager.execute()`): use `waitForTransactionConfirmation()` — handles polling, returns confirmed tx.
- **Wallet adapter** (`useWallet().executeTransaction()`): use manual `setInterval` with `transactionStatus()` — wallet returns `shield_...` tracking ID, not `at1...` on-chain ID. See `wallet-integration.md`.

### Credit Operations
```typescript
// Transfer credits
const txId = await pm.transfer(
    1.5,                // amount in credits
    "aleo1receiver...", // recipient
    "public",           // "public" | "private" | "publicToPrivate" | "privateToPublic"
    0.2,                // fee
);

// Build transfer without submitting
const tx = await pm.buildTransferPublicTransaction(
    1.5, "aleo1receiver...", 0.2
);

// Join two records into one (consolidate UTXOs)
const txId = await pm.join(record1, record2, 0.2);

// Split a record into two
const txId = await pm.split(0.5, record, privateKey);
```

### Staking Operations
```typescript
// Bond credits to a validator (delegate stake)
const txId = await pm.bondPublic(
    "aleo1validator...",    // validator address
    "aleo1withdrawal...",   // withdrawal address
    1000,                   // amount in microcredits
);

// Unbond (start unstaking period)
const txId = await pm.unbondPublic("aleo1staker...", 500);

// Claim unbonded credits (after unbonding period)
const txId = await pm.claimUnbondPublic("aleo1staker...");

// Set validator state (for validator operators)
const txId = await pm.setValidatorState(true); // true = open, false = closed
```

### Offline / Local Execution
```typescript
// Run locally without submitting to network
const result = await pm.run(
    program,           // program source code as string
    "hello",           // function name
    ["5u32", "5u32"],  // inputs
    false              // proveExecution
);
const output = result.getOutputs();
```

### Deploy a Program
```typescript
const txId = await pm.deploy(program, 3.8);

// Or build without submitting
const tx = await pm.buildDeploymentTransaction(program, 3.8);
```

### Key Synthesis and Verification
```typescript
// Pre-synthesize keys for a function (avoids cold-start on first execution)
await pm.synthesizeKeys("my_program.aleo", "my_function", ["1u32", "2u32"]);

// Verify an execution proof
const valid = await pm.verifyExecution(program, fn, inputs, outputs, provingKey, verifyingKey);

// Verify program structure
const valid = await pm.verifyProgram(programSource);
```

## Utility Functions

### retryWithBackoff
```typescript
import { retryWithBackoff } from '@provablehq/sdk/testnet.js';

const result = await retryWithBackoff(
    () => networkClient.getTransaction(txId),
    {
        maxAttempts: 5,      // default: 5
        baseDelay: 100,      // default: 100ms
        jitter: 50,          // random jitter up to this value (default: baseDelay)
        retryOnStatus: [],   // additional HTTP status codes to retry on
        shouldRetry: (err) => true, // custom retry predicate
    }
);
// Exponential backoff: delay = baseDelay * 2^(attempt-1) + jitter
// Automatically retries on 5xx errors
```

## Web Worker Pattern (Required for Browser)

All `@provablehq/sdk` imports in browser apps must live in a Web Worker. This prevents blocking the main thread during ZK proof generation.

**workers/AleoWorker.ts:**
```typescript
import {
    Account, ProgramManager, initThreadPool,
    AleoKeyProvider, AleoNetworkClient, NetworkRecordProvider
} from "@provablehq/sdk/testnet.js";
import { expose } from "comlink";

await initThreadPool();

async function executeProgram(program: string, functionName: string, inputs: string[]) {
    const pm = new ProgramManager();
    const account = new Account();
    pm.setAccount(account);
    const result = await pm.run(program, functionName, inputs, false);
    return result.getOutputs();
}

const workerAPI = { executeProgram };
expose(workerAPI);
```

**App.tsx:**
```tsx
import { wrap } from "comlink";

const worker = new Worker(new URL("./workers/AleoWorker.ts", import.meta.url), {
    type: "module"
});
const api = wrap<typeof import("./workers/AleoWorker")>(worker);

const outputs = await api.executeProgram(programSource, "hello", ["5u32", "5u32"]);
```

**Rules:**
- `initThreadPool()` runs inside the worker, not the main thread
- All `@provablehq/sdk` imports stay in the worker file
- UI components call worker methods via Comlink as async functions
- Show loading/progress state for proving operations (they take time)

## Delegated Proving Service (DPS)

Offload expensive proof generation to Provable's remote provers:
```typescript
const provingRequest = await pm.provingRequest({
    programName: "credits.aleo",
    functionName: "transfer_public",
    baseFee: 0.2,
    inputs: ["aleo1receiver...", "1000000u64"],
    broadcast: true,
});

const response = await pm.networkClient.submitProvingRequest({
    provingRequest,
    url: "https://api.provable.com/prove/testnet/prove",
    apiKey: jwtToken,
});
```

Configure via `AleoNetworkClient` constructor options: `proverUri`, `recordScannerUri`.

## ES Module Compatibility

All packages are ESM-only (`"type": "module"`). In `package.json`:
```json
{ "type": "module" }
```

## Network Endpoints

| Network | API Endpoint |
|---------|-------------|
| Mainnet | `https://api.explorer.provable.com/v1` |
| Testnet | `https://api.explorer.provable.com/v1` |

## Important Notes

- **Network-specific imports required**: `@provablehq/sdk/testnet.js` or `/mainnet.js` — never bare package
- **Browser: all SDK calls in Web Worker** — never import SDK in main thread
- **Browser: SDK supplements wallet adapter** — wallet handles transactions, SDK handles crypto/introspection
- **`initThreadPool()` required** before any program execution (in worker for browser, top-level for Node)
- **Exclude `@provablehq/wasm` from bundler optimization** (not `@provablehq/sdk`)
- **COOP/COEP headers required** for WASM + SharedArrayBuffer
- Proof generation is CPU-intensive — use Web Workers in browser, delegated proving for best UX
- For Leo programs, compile to Aleo Instructions first (`leo build`), then load `.aleo` as string
