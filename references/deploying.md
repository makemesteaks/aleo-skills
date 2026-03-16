# Deploying Programs

## Prerequisites
- Leo CLI installed (`leo --version`)
- Aleo account with credits (for fees)
- Private key in `.env` file: `PRIVATE_KEY=APrivateKey1...`

## Deployment via Leo CLI

### Build First
```bash
leo build
```
This compiles Leo → Aleo Instructions and generates proving/verifying keys in `build/`.

### Deploy to Network
```bash
# Deploy to testnet (estimates fees but does NOT broadcast)
leo deploy

# Actually broadcast to the network (required to deploy on-chain)
leo deploy --broadcast

# Deploy with explicit endpoint
leo deploy --endpoint https://api.explorer.provable.com/v1 --broadcast
```

**Important:** Without `--broadcast`, `leo deploy` only estimates fees and exits. You must pass `--broadcast` to actually submit the deployment transaction.

### Deploy with Custom Fee
```bash
leo deploy --priority-fee 1000  # fee in microcredits
```

## Deployment via SDK

```typescript
import { ProgramManager, AleoKeyProvider, NetworkRecordProvider } from '@provablehq/sdk';

const pm = new ProgramManager("https://api.explorer.provable.com/v1", keyProvider, recordProvider);
pm.setAccount(account);

// Load compiled program (Aleo Instructions, not Leo source)
const program = "program my_program.aleo;\n\nfunction hello:...";

// Deploy with fee (in credits)
const txId = await pm.deploy(program, 3.8);

// Or build without submitting
const tx = await pm.buildDeploymentTransaction(program, 3.8);
```

### Fee Estimation
```typescript
import { ProgramManagerBase } from '@provablehq/sdk';
const estimatedFee = await ProgramManagerBase.estimateDeploymentFee(program);
```

## Executing Programs On-Chain

### Via Leo CLI
```bash
# Run locally (no transaction, no fees)
leo run <function_name> <input_1> <input_2> ...

# Execute on-chain (creates transaction, requires fees)
leo execute <function_name> <input_1> <input_2> ... --broadcast
```

### Input Format
Inputs must include type suffixes:
```bash
leo run hello 5u32 10u32
leo run transfer "{owner: aleo1..., amount: 100u64}" aleo1receiver... 50u64
```

Record inputs are JSON-like with type annotations.

## Program Naming Rules

- Format: `name.aleo` (e.g., `my_token.aleo`)
- Must be **unique on-chain** — check availability before deploying
- Names are permanent — cannot be changed after deployment
- Alphanumeric + underscores only, must start with a letter
- Convention: lowercase with underscores (e.g., `dark_forest.aleo`)

## Signing Transactions

### From .env
The `.env` file in your project root:
```
PRIVATE_KEY=APrivateKey1zkp...
ENDPOINT=https://api.explorer.provable.com/v1
NETWORK=testnet
```

### Account Generation
```bash
leo account new
```
Outputs: private key, view key, address. Save these securely.

## Local Development with Devnet

Run a local Aleo network for testing:
```bash
leo devnode
```

This starts a local node that:
- Produces blocks automatically
- Provides a local API endpoint
- Has pre-funded accounts
- Resets on restart

### Devnode Commands
```bash
leo devnode                    # Start local network
leo devnode --help             # Show options
```

### Deploy to Devnode
```bash
leo deploy --endpoint http://localhost:3030
leo execute <function> <args> --endpoint http://localhost:3030 --broadcast
```

## Delegated Proving

For better UX, offload proof generation to Provable's infrastructure instead of generating proofs locally (which is slow).

See `frontend-sdk.md` for delegated proving setup with the SDK.

## Deployment Checklist

1. **Has constructor**: every program must have a `constructor` (required since ConsensusVersion::V9). Use `@noupgrade async constructor() {}` for non-upgradable programs. See [upgradability.md](upgradability.md) for upgrade modes.
2. **Build cleanly**: `leo build` succeeds with no warnings
3. **Test locally**: `leo run` and `leo test` pass
4. **Check program name**: ensure it's unique on-chain
4. **Estimate fees**: `leo deploy` (without `--broadcast`)
5. **Fund account**: ensure deployer has sufficient credits
6. **Deploy**: `leo deploy --broadcast`
7. **Verify**: check transaction on [Provable Explorer](https://explorer.provable.com/)
8. **Test on-chain**: execute functions via `leo execute --broadcast`

## Common Deployment Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Insufficient balance" | Not enough credits | Fund the account via faucet or transfer |
| "Program already exists" | Name taken on-chain | Choose a different program name |
| "Transaction too large" | Program exceeds 128 KB | Modularize into smaller programs |
| "Fee too low" | Priority fee insufficient | Increase `--priority-fee` |
| "Program not found" after deploy | Deployed without `--broadcast` | Re-deploy with `--broadcast` flag, verify TX on explorer |
| "must contain a constructor" | Missing constructor (V9+) | Add `@noupgrade async constructor() {}` to your program |
