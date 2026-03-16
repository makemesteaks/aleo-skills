# Toolchain & Setup

## Required Tools

### 1. Rust Toolchain
Leo is written in Rust. Install via rustup:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup update
```

### 2. Leo CLI
```bash
# Install from crates.io (recommended)
cargo install leo-lang

# Or build from source
git clone https://github.com/ProvableHQ/leo
cd leo
cargo install --path crates/leo

# Verify
leo --version

# Update
leo update
```

### 3. Node.js (for frontend/SDK)
Node.js 18+ required for `@provablehq/sdk` and `create-leo-app`.
```bash
node --version  # Must be >= 18
```

### 4. snarkVM (not a CLI — understanding the architecture)
snarkVM is the **Rust library** powering Aleo's ZK execution. It provides circuits, curves, fields, ledger primitives, and the proof system. Developers never invoke snarkVM directly — Leo CLI compiles to Aleo Instructions which snarkVM executes under the hood.

```
Developer → Leo CLI → (compiles to) → Aleo Instructions → (executed by) → snarkVM Runtime
```

- snarkVM is a **dependency**, not a tool you install or run
- Leo depends on snarkVM for cryptographic operations
- If you see `snarkvm` in error logs, it's the runtime — not something to configure

### 5. snarkOS (optional — for running a local node)
```bash
git clone --branch mainnet --single-branch https://github.com/AleoNet/snarkOS.git
cd snarkOS

# Ubuntu helper
./build_ubuntu.sh

# Install
cargo install --locked --path .
```

#### snarkOS Hardware Requirements
| Component | Minimum |
|-----------|---------|
| CPU | 16 cores (32 preferred) |
| RAM | 16 GB |
| Storage | 128 GB |
| Network | 250 Mbps |

## Project Setup

### New Leo Project
```bash
leo new my_project
cd my_project
```

Creates:
```
my_project/
├── program.json        # Project metadata, dependencies
├── .env                # PRIVATE_KEY (auto-generated)
├── src/
│   └── main.leo        # Program source
├── inputs/
│   └── my_project.in   # Default input file
└── outputs/            # Execution outputs
```

### Scaffold a Full-Stack dApp
```bash
npm create leo-app@latest
```

Creates a React + Leo project with SDK integration, Web Worker setup, and wallet connection boilerplate.

## Leo CLI Commands

| Command | Description |
|---------|-------------|
| `leo new <name>` | Create new project |
| `leo build` | Compile Leo → Aleo Instructions |
| `leo run <function> [args]` | Execute locally (no fees) |
| `leo execute <function> [args] --broadcast` | Execute on-chain (requires fees) |
| `leo test` | Run `@test` transitions |
| `leo deploy` | Deploy to network |
| `leo deploy` (without `--broadcast`) | Estimate deployment fee |
| `leo add <program>` | Add dependency from network |
| `leo add <program> --local <path>` | Add local dependency |
| `leo account new` | Generate new account |
| `leo devnode` | Start local development network |
| `leo debug` | Start interactive debugger |
| `leo update` | Update Leo CLI |
| `leo clean` | Remove build artifacts |

## Build Output

After `leo build`, the `build/` directory contains:
- Aleo Instructions (`.aleo` files) — the compiled bytecode
- Proving keys and verifying keys for each transition
- ABI (JSON) — type information for SDK integration

## Environment Configuration

### .env File
```
PRIVATE_KEY=APrivateKey1zkp...
ENDPOINT=https://api.explorer.provable.com/v1
NETWORK=testnet
```

### Network Endpoints
| Network | Endpoint |
|---------|----------|
| Testnet | `https://api.explorer.provable.com/v1` |
| Mainnet | `https://api.explorer.provable.com/v1` |
| Local devnet | `http://localhost:3030` |

## Version Compatibility

- Leo requires a specific Rust nightly or stable version — `rustup update` handles this
- SDK version should match the network version (testnet vs mainnet)
- snarkOS version must match the network you're connecting to (use the `mainnet` branch for mainnet)
- `create-leo-app` pulls the latest compatible SDK version automatically
