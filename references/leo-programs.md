# Writing Leo Programs

## Project Structure
```
my_program/
├── program.json        # Program metadata (name, version, dependencies)
├── .env                # Private key for deployment/execution
├── src/
│   └── main.leo        # Program source code
├── inputs/
│   └── my_program.in   # Input files for testing
├── outputs/            # Generated outputs
└── build/              # Compiled artifacts (Aleo Instructions, keys, ABI)
```

Create a new project:
```bash
leo new my_program
cd my_program
```

## Program Skeleton
```leo
program my_program.aleo {
    // 1. Structs — value types for grouping data
    struct Info {
        title: field,
        amount: u64,
    }

    // 2. Records — private UTXO data (must have `owner`)
    record Token {
        owner: address,
        amount: u64,
    }

    // 3. Mappings — public on-chain key-value storage
    mapping balances: address => u64;

    // 4. Storage variables — single on-chain values
    storage total_supply: u64;

    // 5. Storage vectors — on-chain dynamic arrays
    storage whitelist: [address];

    // 6. Transitions — entry points (off-chain, produce ZK proofs)
    transition mint(receiver: address, amount: u64) -> Token {
        return Token { owner: receiver, amount: amount };
    }

    // 7. Async transitions — entry points that also mutate on-chain state
    async transition mint_public(public receiver: address, public amount: u64) -> Future {
        return finalize_mint_public(receiver, amount);
    }

    // 8. Async functions (finalize) — on-chain logic
    async function finalize_mint_public(public receiver: address, public amount: u64) {
        let current: u64 = Mapping::get_or_use(balances, receiver, 0u64);
        Mapping::set(balances, receiver, current + amount);
    }

    // 9. Helper functions — private logic, not callable externally
    function compute(a: u64, b: u64) -> u64 {
        return a * b;
    }

    // 10. Constructor — controls upgradability
    @noupgrade
    async constructor() {}
}
```

## Records: The Private Data Model

Records are Aleo's core privacy primitive. They work like UTXOs:
- Each record has an `owner` address
- Only the owner can consume (spend) a record
- Consuming a record destroys it and creates new records as output
- Records are encrypted on-chain — only the owner can decrypt them
- A record used as transition input is spent (gone forever)

### Record Lifecycle
```
┌──────────┐     ┌──────────────┐     ┌──────────────┐
│  Create   │ ──► │   Exists     │ ──► │  Consumed    │
│  (mint)   │     │  (spendable) │     │  (destroyed) │
└──────────┘     └──────────────┘     └──────────────┘
                        │
                        ▼
                 New records created
                 as transition output
```

### Token Transfer Pattern (most common)
```leo
record Token {
    owner: address,
    amount: u64,
}

// Private transfer: consumes sender's record, creates two new records
transition transfer(sender: Token, to: address, amount: u64) -> (Token, Token) {
    let change: u64 = sender.amount - amount;  // underflow = proof failure = reverts
    let remaining: Token = Token { owner: sender.owner, amount: change };
    let sent: Token = Token { owner: to, amount: amount };
    return (remaining, sent);
}
```

### Record with Multiple Fields
```leo
record NFT {
    owner: address,
    metadata: field,     // hash of metadata
    edition: u64,
    transferable: bool,
}

transition transfer_nft(nft: NFT, to: address) -> NFT {
    assert(nft.transferable);  // enforce transfer rules
    return NFT {
        owner: to,
        metadata: nft.metadata,
        edition: nft.edition,
        transferable: nft.transferable,
    };
}
```

### Multi-Record Input Pattern
```leo
// Merge two records into one (consolidate UTXOs)
transition merge(a: Token, b: Token) -> Token {
    return Token {
        owner: a.owner,
        amount: a.amount + b.amount,
    };
}

// Split one record into two
transition split(token: Token, amount: u64) -> (Token, Token) {
    let remaining: u64 = token.amount - amount;
    return (
        Token { owner: token.owner, amount: remaining },
        Token { owner: token.owner, amount: amount }
    );
}
```

## Mappings: Public On-Chain State

Mappings store public data on-chain. They can only be accessed in finalize blocks.

```leo
mapping account: address => u64;

async transition transfer_public(public receiver: address, public amount: u64) -> Future {
    return finalize_transfer(self.caller, receiver, amount);
}

async function finalize_transfer(public sender: address, public receiver: address, public amount: u64) {
    let sender_bal: u64 = Mapping::get_or_use(account, sender, 0u64);
    Mapping::set(account, sender, sender_bal - amount);  // underflow reverts entire tx
    let receiver_bal: u64 = Mapping::get_or_use(account, receiver, 0u64);
    Mapping::set(account, receiver, receiver_bal + amount);
}
```

### External Mapping Reads
Programs can read other programs' mappings (read-only):
```leo
async function finalize_check_balance(addr: address) {
    let bal: u64 = other_token.aleo/balances.get_or_use(addr, 0u64);
    assert(bal >= 100u64);  // require minimum balance in another program
}
```

## Storage Variables & Vectors

### Storage Variables (single on-chain values)
```leo
storage admin: address;
storage total_supply: u64;
storage paused: bool;

async function finalize_init(deployer: address) {
    admin = deployer;
    total_supply = 0u64;
    paused = false;
}

async function finalize_check() {
    let is_paused: bool = paused.unwrap_or(false);
    assert(!is_paused);
}
```

### Storage Vectors (dynamic on-chain lists)
```leo
storage allowed_minters: [address];

async function finalize_add_minter(minter: address) {
    allowed_minters.push(minter);
}

async function finalize_check_minter(minter: address) {
    let found: bool = false;
    let len: u32 = allowed_minters.len();
    for i: u32 in 0u32..64u32 {
        if i < len {
            let addr: address? = allowed_minters.get(i);
            if addr.unwrap_or(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljuj5) == minter {
                found = true;
            }
        }
    }
    assert(found);
}
```

## Hybrid Pattern: Private Records + Public Mappings

The most powerful Aleo pattern — four transfer modes in one program:

```leo
record Token {
    owner: address,
    amount: u64,
}

mapping account: address => u64;

// 1. Private → Private (fully private, UTXO transfer)
transition transfer_private(sender: Token, to: address, amount: u64) -> (Token, Token) {
    let change: u64 = sender.amount - amount;
    return (
        Token { owner: sender.owner, amount: change },
        Token { owner: to, amount: amount }
    );
}

// 2. Public → Public (fully public, mapping transfer)
async transition transfer_public(public to: address, public amount: u64) -> Future {
    return finalize_transfer_public(self.caller, to, amount);
}

async function finalize_transfer_public(
    public sender: address, public to: address, public amount: u64
) {
    let from_bal: u64 = Mapping::get_or_use(account, sender, 0u64);
    Mapping::set(account, sender, from_bal - amount);
    let to_bal: u64 = Mapping::get_or_use(account, to, 0u64);
    Mapping::set(account, to, to_bal + amount);
}

// 3. Private → Public (consume record, credit public balance)
async transition transfer_private_to_public(
    sender: Token, public receiver: address, public amount: u64
) -> (Token, Future) {
    let change: u64 = sender.amount - amount;
    let remaining: Token = Token { owner: sender.owner, amount: change };
    return (remaining, finalize_priv_to_pub(receiver, amount));
}

async function finalize_priv_to_pub(public receiver: address, public amount: u64) {
    let current: u64 = Mapping::get_or_use(account, receiver, 0u64);
    Mapping::set(account, receiver, current + amount);
}

// 4. Public → Private (debit public balance, mint record)
async transition transfer_public_to_private(
    public receiver: address, public amount: u64
) -> (Token, Future) {
    let token: Token = Token { owner: receiver, amount: amount };
    return (token, finalize_pub_to_priv(self.caller, amount));
}

async function finalize_pub_to_priv(public sender: address, public amount: u64) {
    let current: u64 = Mapping::get_or_use(account, sender, 0u64);
    Mapping::set(account, sender, current - amount);
}
```

## Complete Application Patterns

For privacy-focused patterns (sealed-bid auction, private voting, hybrid tokens), see `privacy-patterns.md`.

### Simple DEX (Token Swap)
```leo
import token_a.aleo;
import token_b.aleo;

program simple_dex.aleo {
    mapping reserves_a: u8 => u64;
    mapping reserves_b: u8 => u64;

    // Swap token A for token B using constant product formula
    async transition swap_a_for_b(
        input: token_a.aleo/Token,
        public amount_in: u64,
        public min_amount_out: u64
    ) -> (token_a.aleo/Token, token_b.aleo/Token, Future) {
        // Consume input token, return change + output token
        let change: token_a.aleo/Token = token_a.aleo/transfer(input, self.caller, input.amount - amount_in);
        let output: token_b.aleo/Token = token_b.aleo/mint(self.caller, min_amount_out);
        return (change, output, finalize_swap(amount_in, min_amount_out));
    }

    async function finalize_swap(public amount_in: u64, public min_out: u64) {
        let ra: u64 = Mapping::get_or_use(reserves_a, 0u8, 0u64);
        let rb: u64 = Mapping::get_or_use(reserves_b, 0u8, 0u64);

        // Constant product: (ra + amount_in) * (rb - amount_out) >= ra * rb
        let amount_out: u64 = (rb * amount_in) / (ra + amount_in);
        assert(amount_out >= min_out);  // slippage protection

        Mapping::set(reserves_a, 0u8, ra + amount_in);
        Mapping::set(reserves_b, 0u8, rb - amount_out);
    }
}
```

## Authorization Patterns

### Caller Check (Admin)
```leo
transition admin_action() {
    assert_eq(self.caller, aleo1admin_address_here...);
    // ... privileged logic
}
```

### Caller vs Signer
```leo
// self.caller = immediate caller (could be another program)
// self.signer = original transaction signer
transition sensitive_action() {
    // Use self.caller for program-to-program authorization
    assert_eq(self.caller, aleo1trusted_program...);

    // Use self.signer for user identity verification
    assert_eq(self.signer, aleo1authorized_user...);
}
```

### Ownership Verification
Records inherently enforce ownership — only the record owner can pass it as input to a transition.

### Time-Gated Actions
```leo
mapping unlock_at: u8 => u32;

async transition claim() -> Future {
    return finalize_claim();
}

async function finalize_claim() {
    let unlock_height: u32 = Mapping::get_or_use(unlock_at, 0u8, 0u32);
    assert(block.height >= unlock_height);
}
```

## Common Patterns

### Bounded Loop with Conditional
```leo
// Loops must have constant bounds — use max bound + conditional exit
function calculate(principal: u64, rate: u64, periods: u64) -> u64 {
    let amount: u64 = principal;
    for i: u64 in 0u64..100u64 {
        if i < periods {
            amount += (amount * rate) / 10000u64;
        }
    }
    return amount;
}
```

### ID Generation via Hashing
```leo
let id: field = BHP256::hash_to_field(info.title);
```

### Struct as Configuration
```leo
struct Config {
    fee_rate: u64,
    min_amount: u64,
    max_amount: u64,
    admin: address,
}
```

### Using Inline for Reusable Logic
```leo
inline min(a: u64, b: u64) -> u64 {
    return (a < b) ? a : b;
}

inline max(a: u64, b: u64) -> u64 {
    return (a > b) ? a : b;
}

transition process(amount: u64) -> u64 {
    let capped: u64 = min(amount, 1000u64);
    return max(capped, 1u64);
}
```

## Cross-Program Calls
```leo
import token.aleo;

program exchange.aleo {
    // Call transition from imported program
    transition swap(input: token.aleo/Token) -> token.aleo/Token {
        let result: token.aleo/Token = token.aleo/transfer(input, self.caller, input.amount);
        return result;
    }
}
```

Rules:
- Transitions can call external transitions (from imported programs)
- Each cross-program call adds to transaction size (128 KB max)
- Max import depth: 64, max call depth: 31

## Build & Run Commands
```bash
leo build                           # Compile the program
leo run <function> <args...>        # Execute a transition locally
leo test                            # Run @test transitions
leo deploy                          # Deploy to network
leo execute <function> <args...>    # Execute on-chain (--broadcast)
leo debug <function> <args...>      # Interactive debugger
```

## Production Patterns
*From the Verulink bridge protocol (venture23-aleo/verulink) — a real-world multi-program Leo application.*

### Mapping-as-Variables
Use a single mapping with constant integer keys to store multiple config values (avoids many separate mappings):
```leo
mapping bridge_settings: u8 => u8;
const THRESHOLD_INDEX: u8 = 1u8;
const TOTAL_INDEX: u8 = 2u8;
const PAUSED_INDEX: u8 = 3u8;
```

### Fixed-Size Array with Null Padding
Leo has no dynamic arrays. Use fixed arrays with a zero/null sentinel:
```leo
const ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
// Pass [address; 5], pad unused slots with ZERO_ADDRESS
// In finalize: check addr != ZERO_ADDRESS before processing
```

### Struct Hashing for Deduplication
Hash structured data to create unique keys and prevent duplicate actions:
```leo
let vote_hash: field = BHP256::hash_to_field(
    ProposalVote { proposal: proposal_hash, member: self.caller }
);
assert(!Mapping::contains(votes, vote_hash)); // prevent double-vote
```

### Ownership via Mapping
Single-owner access control using a mapping instead of hardcoded addresses:
```leo
mapping owner_TB: bool => address;
// In finalize: assert_eq(self.caller, Mapping::get(owner_TB, true));
```

### Finalize-Heavy Architecture
Keep transition bodies minimal — pass params through, put all state logic in finalize. Transitions generate proofs; finalize does state validation and mutation.

### Cross-Program Atomic Execution
Execute an action and verify authorization atomically — if the authorization call reverts, everything reverts:
```leo
transition add_member(new_member: address, proposal_id: field) {
    program_a.aleo/add(new_member);
    council.aleo/external_execute(proposal_id); // reverts everything if unauthorized
}
```

## Program Limits
| Limit | Value |
|-------|-------|
| Max program size (compiled) | 100 KB |
| Max mappings per program | 31 |
| Max functions per program | 31 |
| Max structs per program | 310 |
| Max records per program | 310 |
| Max imports per program | 64 |
| Max import depth | 64 |
| Max call depth | 31 |
| Max transaction size | 128 KB |
