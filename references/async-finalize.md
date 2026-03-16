# Async Functions & Finalize

## The Dual Execution Model

Aleo programs execute in two phases:

1. **Transition (off-chain)**: runs locally on the user's machine, consumes/produces records, generates a ZK proof. This is private.
2. **Finalize (on-chain)**: runs on the network after the proof is verified. Can read/write public mappings. This is public.

```
User's Machine                          Aleo Network
┌─────────────────┐                    ┌──────────────────┐
│ async transition │ ── ZK proof ──►   │ async function   │
│ (off-chain)      │                   │ (finalize)       │
│ • consume records│                   │ • read mappings  │
│ • produce records│                   │ • write mappings │
│ • private inputs │                   │ • public state   │
└─────────────────┘                    └──────────────────┘
```

## Syntax

### Basic Async Transition + Finalize
```leo
mapping counter: address => u64;

async transition increment(public amount: u64) -> Future {
    // Off-chain: can access self.caller, produce records, etc.
    return finalize_increment(self.caller, amount);
}

async function finalize_increment(public caller: address, public amount: u64) {
    // On-chain: can read/write mappings
    let current: u64 = Mapping::get_or_use(counter, caller, 0u64);
    Mapping::set(counter, caller, current + amount);
}
```

### Returning Records + Future
```leo
record Token {
    owner: address,
    amount: u64,
}

mapping supply: u8 => u64;

async transition mint(receiver: address, amount: u64) -> (Token, Future) {
    let token: Token = Token { owner: receiver, amount: amount };
    return (token, finalize_mint(amount));
}

async function finalize_mint(public amount: u64) {
    let current: u64 = Mapping::get_or_use(supply, 0u8, 0u64);
    Mapping::set(supply, 0u8, current + amount);
}
```

The return type is `(Token, Future)` — a record AND a finalize future.

## Mapping Operations (Finalize Only)

These can ONLY be used inside `async function` blocks:

```leo
// Get value (fails if key doesn't exist)
let val: u64 = Mapping::get(balances, key);

// Get value with default (safe)
let val: u64 = Mapping::get_or_use(balances, key, 0u64);

// Set value (create or update)
Mapping::set(balances, key, value);

// Check if key exists
let exists: bool = Mapping::contains(balances, key);

// Delete a key
Mapping::remove(balances, key);
```

## Finalize-Specific Features

### Block Height
```leo
async function finalize_time_check() {
    // block.height is only available in finalize
    assert(block.height > 1000u32);
}
```

### Revert Behavior
If any operation in finalize fails (assertion, overflow, missing mapping key with `get`), the **entire transaction** is reverted — including all record changes from the transition.

## Design Patterns

### Pattern: Conditional Public State Update
```leo
async transition transfer_public(public to: address, public amount: u64) -> Future {
    return finalize_transfer(self.caller, to, amount);
}

async function finalize_transfer(
    public from: address,
    public to: address,
    public amount: u64
) {
    // Debit sender
    let from_bal: u64 = Mapping::get_or_use(account, from, 0u64);
    Mapping::set(account, from, from_bal - amount);  // underflow reverts

    // Credit receiver
    let to_bal: u64 = Mapping::get_or_use(account, to, 0u64);
    Mapping::set(account, to, to_bal + amount);  // overflow reverts
}
```

### Pattern: Private Action + Public Accounting
```leo
async transition deposit(token: Token, amount: u64) -> (Token, Future) {
    let remaining: u64 = token.amount - amount;
    let change: Token = Token { owner: token.owner, amount: remaining };
    let hash: field = BHP256::hash_to_field(token.owner);
    return (change, finalize_deposit(hash, amount));
}

async function finalize_deposit(hash: field, amount: u64) {
    let current: u64 = Mapping::get_or_use(balances, hash, 0u64);
    Mapping::set(balances, hash, current + amount);
}
```

### Pattern: Time-Locked Operations
```leo
mapping lock_until: address => u32;

async transition withdraw(amount: u64) -> (Token, Future) {
    let token: Token = Token { owner: self.caller, amount: amount };
    return (token, finalize_withdraw(self.caller));
}

async function finalize_withdraw(public caller: address) {
    let unlock_height: u32 = Mapping::get_or_use(lock_until, caller, 0u32);
    assert(block.height >= unlock_height);
}
```

## Key Rules

1. **Mappings are finalize-only**: you cannot read or write mappings in transitions
2. **Transitions are private, finalize is public**: anything passed to finalize becomes public
3. **Finalize failure reverts everything**: if finalize fails, the transition's record changes are also reverted
4. **`self.caller` is transition-only**: in finalize, pass the caller explicitly as a parameter
5. **`block.height` is finalize-only**: not available in transitions
6. **Return `Future`**: async transitions must return a `Future` (the finalize call)
7. **One finalize per transition**: each async transition has exactly one corresponding async function
