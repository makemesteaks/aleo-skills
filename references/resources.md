# Ecosystem Resources

## Official Documentation
- [Leo Language Docs](https://docs.leo-lang.org/) — language reference, guides, API
- [Aleo Developer Docs](https://developer.aleo.org/) — SDK, deployment, network guides
- [Provable SDK API Docs](https://docs.explorer.provable.com/docs/sdk/) — TypeScript SDK reference

## Core Repositories
- [ProvableHQ/leo](https://github.com/ProvableHQ/leo) — Leo compiler
- [ProvableHQ/snarkVM](https://github.com/ProvableHQ/snarkVM) — Zero-knowledge virtual machine
- [ProvableHQ/snarkOS](https://github.com/ProvableHQ/snarkOS) — Aleo node software
- [ProvableHQ/sdk](https://github.com/ProvableHQ/sdk) — JavaScript/TypeScript SDK
- [ProvableHQ/aleo-dev-toolkit](https://github.com/ProvableHQ/aleo-dev-toolkit) — Wallet adapters and hooks
- [ProvableHQ/leo-examples](https://github.com/ProvableHQ/leo-examples) — Example Leo programs
- [ProvableHQ/leo-docs-source](https://github.com/ProvableHQ/leo-docs-source) — Documentation source

## Developer Tools
- [Leo Playground](https://play.leo-lang.org/) — Web IDE for Leo (build, test, deploy in browser)
- [Provable Tools](https://provable.tools) — Account management, program execution, transfers
- [Aleo Explorer](https://explorer.aleo.org/) — Block explorer, transaction viewer
- [create-leo-app](https://www.npmjs.com/package/create-leo-app) — `npm create leo-app@latest`

## IDE Support
- [VS Code Extension](https://marketplace.visualstudio.com/items?itemName=aleohq.leo-extension) — Syntax highlighting for Leo
- [IntelliJ Plugin](https://plugins.jetbrains.com/plugin/19890-leo) — Leo support for JetBrains IDEs
- [Sublime Text](https://github.com/AleoHQ/leo-sublime) — Leo syntax highlighting

## Example Programs (ProvableHQ/leo-examples)
| Example | Description | Key Concepts |
|---------|-------------|--------------|
| `helloworld` | Minimal program (a + b) | Basic transition |
| `simple_token` | Private token mint & transfer | Records, ownership |
| `token` | Full token with public + private modes | Records, mappings, hybrid patterns |
| `auction` | First-price sealed-bid auction | Private bids, record ownership transfer |
| `vote` | Private voting with public tallies | Tickets, anonymous voting |
| `basic_bank` | Bank with interest calculation | Deposit/withdraw, bounded loops |
| `battleship` | Multi-program game | Imports, cross-program calls |
| `tictactoe` | Two-player game | Game state management |
| `lottery` | Random lottery | Randomness patterns |
| `fibonacci` | Fibonacci sequence | Bounded computation |

## Network Information

### API Endpoints
| Network | Endpoint |
|---------|----------|
| Mainnet | `https://api.explorer.provable.com/v1` |
| Testnet | `https://api.explorer.provable.com/v1` |

### Faucet
Testnet credits can be obtained via the [Aleo Faucet](https://faucet.aleo.org/) or by generating a new account in the Leo Playground.

## Community
- [Discord](https://discord.com/invite/aleo) — Developer community
- [AleoNet/awesome-aleo](https://github.com/AleoNet/awesome-aleo) — Curated resource list
- [Aleo Blog](https://aleo.org/blog/) — Official announcements and technical posts
- [AleoNet/workshop](https://github.com/AleoNet/workshop) — Workshop starter guide

## Migration Guides
- [Solidity to Leo Migration Guide](https://developer.aleo.org/guides/solidity-to-leo/migration-guide) — For Ethereum developers
