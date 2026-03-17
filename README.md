> ⚠️ This project is in early development. APIs and skill content may change.

# Aleo Skills

Agent skills for [Aleo](https://aleo.org)/[Leo](https://leo-lang.org) blockchain development.

Covers Leo programs, `@provablehq/sdk` frontend integration, wallet connection, testing,
deployment, ZK privacy patterns, and common debugging.

## Installation

### Claude Code Plugin (recommended)

```bash
/plugin marketplace add makemesteaks/aleo-skills
/plugin install aleo-skills@aleo-skills
```

### Install Script

```bash
git clone https://github.com/makemesteaks/aleo-skills
cd aleo-skills

./install.sh              # install locally (current project)
./install.sh --global     # install globally (all projects)
./install.sh --force      # overwrite existing installation
```

| Flag | Description |
|------|-------------|
| `--global`, `-g` | Install to `~/.claude/skills/` (all projects) |
| `--local` | Install to `./.claude/skills/` (current project, default) |
| `--force`, `-f` | Overwrite if already installed |
| `--yes`, `-y` | Skip confirmation prompt |

## What's Included

**`aleo-leo`** skill covers:
- Leo programs: records (private), mappings (public), transitions, finalize blocks
- Frontend: `@provablehq/sdk`, Vite config, Web Worker pattern, delegated proving
- Wallets: `@provablehq/aleo-wallet-adaptor-*`, executeTransaction, status polling
- Testing: `leo test`, unit tests, async/finalize testing
- Deployment: Leo CLI, fees, program naming, testnet/mainnet
- Security: ZK vulnerabilities, overflow, record ownership, mapping races
- Privacy patterns: records vs mappings, hybrid patterns, sealed-bid auctions
- Debugging: Leo compiler errors, runtime errors, common pitfalls
