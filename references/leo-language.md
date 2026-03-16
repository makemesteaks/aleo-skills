# Leo Language Reference

## Program Structure
Every Leo file defines a single program:
```leo
import other_program.aleo;

program name.aleo {
    // structs, records, mappings, storage, transitions, functions
}

// Tests go outside the program block
@test
transition test_something() { ... }
```
Program names must end with `.aleo`, be unique on-chain, alphanumeric + underscores, start with a letter.

## Data Types

### Primitives
| Type | Description | Example |
|------|-------------|---------|
| `bool` | Boolean | `true`, `false` |
| `u8`–`u128` | Unsigned integers | `42u64` |
| `i8`–`i128` | Signed integers | `-7i32` |
| `field` | Field element (~253 bits) | `1field` |
| `group` | Elliptic curve point | `0group` |
| `scalar` | Scalar field element | `1scalar` |
| `address` | Aleo address | `aleo1...` |
| `signature` | Schnorr signature | — |

**Critical**: All integer literals require a type suffix (`42u64`, not `42`).

### Type Casting
```leo
let a: u8 = 255u8;
let b: u16 = a as u16;       // widening cast
let c: u32 = b as u32;
let d: i32 = c as i32;       // unsigned → signed

let f: field = 10field;
let i: i32 = f as i32;       // field → integer
let u: u64 = f as u64;       // field → unsigned

let s: scalar = 5scalar;
let sf: field = s as field;   // scalar → field

let g: group = 1group;
let gf: field = g as field;   // group → field

let addr: address = aleo1...;
let af: field = addr as field; // address → field (one-way, no reverse)
```
You can cast between all primitive types **except `signature`**. Address → field is one-way only.

### Option Types
```leo
// Any type (except address and signature) can be optional
let b_some: bool? = true;
let b_none: bool? = none;

let val: bool = b_some.unwrap();           // panics if none
let safe: bool = b_none.unwrap_or(false);  // returns default if none

// Works with integers, field, group, scalar
let amount: u64? = 100u64;
let missing: u64? = none;

// Works with structs (if struct has no address/signature fields)
struct Point { x: u32, y: u32 }
let p: Point? = Point { x: 1u32, y: 2u32 };
let q: Point? = none;
let val: Point = q.unwrap_or(Point { x: 0u32, y: 0u32 });
```
**Restrictions**: `address` and `signature` types have no option variants. Structs containing `address` or `signature` fields also cannot be optional.

### Composite Types

#### Structs
```leo
struct TokenInfo {
    supply: u64,
    decimals: u8,
}

let info: TokenInfo = TokenInfo { supply: 1000000u64, decimals: 6u8 };
let s: u64 = info.supply;

// External struct reference
let ext: other_program.aleo/SomeStruct = ...;
```

#### Const Generics on Structs
```leo
struct Matrix::[N: u32, M: u32] {
    data: [field; N * M],
}

let m: Matrix::[2, 2] = Matrix::[2, 2] { data: [0field, 1field, 2field, 3field] };
```
Acceptable const generic types: integer types, `bool`, `scalar`, `group`, `field`, `address`.
Note: generic structs cannot currently be imported across programs.

#### Records
```leo
record Token {
    owner: address,   // required field
    amount: u64,
}

let t: Token = Token { owner: self.caller, amount: 100u64 };
let a: u64 = t.amount;
```

#### Arrays (fixed-size only)
```leo
let arr: [u32; 4] = [1u32, 2u32, 3u32, 4u32];
let first: u32 = arr[0];
let empty: [u8; 0] = [];

// Loop over array
let sum: u32 = 0u32;
for i: u8 in 0u8..4u8 {
    sum += arr[i];
}
```

#### Tuples
```leo
let t: (u8, bool, field) = (42u8, true, 100field);

// Destructuring
let (a, b, c) = t;

// Index access
let first: u8 = t.0;
let second: bool = t.1;
```
Tuples cannot be empty.

## On-Chain Storage (finalize-only)

### Mappings
```leo
mapping balances: address => u64;

// In async function (finalize):
let exists: bool = balances.contains(addr);
let val: u64 = balances.get(addr);                    // fails if missing
let safe: u64 = balances.get_or_use(addr, 0u64);     // returns default
balances.set(addr, 100u64);                            // create or update
balances.remove(addr);                                 // delete

// External mappings (read-only, from other programs)
let ext: u64 = other_program.aleo/balances.get_or_use(addr, 0u64);
let ext_exists: bool = other_program.aleo/balances.contains(addr);
```

### Storage Variables
```leo
storage counter: u64;

// In async function:
let val: u64 = counter.unwrap();              // fails if not set
let safe: u64 = counter.unwrap_or(0u64);      // returns default
counter = 42u64;                               // set value
counter = none;                                // clear value

// External (read-only)
let ext: u64 = other_program.aleo/counter.unwrap_or(0u64);
```

### Storage Vectors
```leo
storage items: [u64];

// In async function:
let length: u32 = items.len();
let val: u64? = items.get(0u32);        // returns option
items.set(0u32, 42u64);                  // set at index
items.push(99u64);                       // append
items.pop();                             // remove last
items.swap_remove(2u32);                 // remove at index (swaps with last)
items.clear();                           // remove all

// External (read-only)
let ext_len: u32 = other_program.aleo/items.len();
let ext_val: u64? = other_program.aleo/items.get(0u32);
```

## Functions

### Call Hierarchy (critical rule)
| Type | Can call | Cannot call |
|------|----------|-------------|
| `transition` | `function`, `inline`, external `transition` | another local `transition` |
| `function` | `inline` only | `function`, `transition` |
| `inline` | `inline` only | `function`, `transition` |

**No recursion** — direct or indirect recursive calls are not allowed.

### Transition (entry point, off-chain)
```leo
transition transfer(sender: Token, to: address, amount: u64) -> (Token, Token) {
    let difference: u64 = sender.amount - amount;
    let remaining: Token = Token { owner: sender.owner, amount: difference };
    let transferred: Token = Token { owner: to, amount: amount };
    return (remaining, transferred);
}
```
- Executes off-chain, generates ZK proof
- `self.caller` — address of the direct caller
- `self.signer` — address of the transaction signer (origin)
- `public` keyword makes an input visible on-chain

### Async Transition + Finalize (on-chain state mutation)
```leo
// Named async function (traditional)
async transition mint_public(public receiver: address, public amount: u64) -> Future {
    return finalize_mint(receiver, amount);
}
async function finalize_mint(public receiver: address, public amount: u64) {
    let current: u64 = Mapping::get_or_use(account, receiver, 0u64);
    Mapping::set(account, receiver, current + amount);
}

// Inline async block (compact alternative — can reference self.caller directly)
async transition mint_public(public receiver: address, public amount: u64) -> Future {
    return async {
        let current: u64 = Mapping::get_or_use(account, self.caller, 0u64);
        Mapping::set(account, self.caller, current + amount);
    };
}
```
For full async/finalize patterns and design guidance, see `async-finalize.md`.

### Helper Function (internal computation)
```leo
function compute(a: u64, b: u64) -> u64 {
    return a + b;
}
```
Cannot produce records. Cannot be called externally. No visibility modifiers on inputs.

### Inline Function (compile-time inlining)
```leo
inline foo(a: field, b: field) -> field {
    return a + b;
}
```
Body is inlined at each call site — no function call overhead in the circuit.

#### Const Generics on Inline Functions
```leo
inline sum_first_n::[N: u32]() -> u32 {
    let sum: u32 = 0u32;
    for i: u32 in 0u32..N {
        sum += i;
    }
    return sum;
}

transition main() -> u32 {
    return sum_first_n::[5u32]();  // N = 5 at compile time
}
```

## Control Flow
```leo
// If-else
if condition {
    // ...
} else if other {
    // ...
} else {
    // ...
}

// Ternary
let x: u32 = condition ? a : b;

// For loop — bounds MUST be compile-time constants
for i: u32 in 0u32..10u32 {
    // ...
}

// Return
return value;
```

**Critical**: No while loops, no dynamic iteration. Loop bounds must be constant. This is a fundamental ZK constraint — the circuit size must be known at compile time.

## Operators

### Arithmetic
`+`, `-`, `*`, `/`, `%`, `**` (pow)

All arithmetic is **checked** — overflow/underflow causes proof failure (transaction reverts).

**Wrapped variants** (overflow wraps around instead of failing):
```leo
let wrapped: u32 = a.add_wrapped(b);
let wrapped: u32 = a.sub_wrapped(b);
let wrapped: u32 = a.mul_wrapped(b);
let wrapped: u32 = a.div_wrapped(b);
let wrapped: u32 = a.pow_wrapped(b);
let wrapped: u32 = a.rem_wrapped(b);
let wrapped: u32 = a.shl_wrapped(b);
let wrapped: u32 = a.shr_wrapped(b);
```

### Signed Integer Operations
```leo
let neg: i64 = -(a as i64);     // negation
let abs: i64 = neg.abs();        // absolute value (also has wrapped variant)
```

### Comparison
`==`, `!=`, `<`, `<=`, `>`, `>=`

### Logical
`&&`, `||`, `!`

### Bitwise
`&`, `|`, `^`, `<<`, `>>`, `!` (NOT)

### Group & Field Operations
```leo
let g: group = group::GEN;                      // generator point
let x: field = 0group.to_x_coordinate();         // x-coordinate
let y: field = 0group.to_y_coordinate();         // y-coordinate
let doubled: field = 1field.double();             // double
let inv: field = 1field.inv();                    // multiplicative inverse
let sq: field = 1field.square();                  // square
let root: field = 1field.square_root();           // square root
```

## Assertions
```leo
assert(condition);              // fails if false
assert_eq(a, b);                // fails if a != b
assert_neq(a, b);               // fails if a == b
```
Assertion failure = proof failure = transaction reverts.

## Cryptographic Operations

### Hash Functions
```leo
// BHP family (algebraic, ZK-friendly, most common)
let h: field = BHP256::hash_to_field(value);
let h: address = BHP256::hash_to_address(value);
let h: group = BHP256::hash_to_group(value);
// Also: BHP512, BHP768, BHP1024

// Poseidon (algebraic, ZK-optimized)
let h: field = Poseidon2::hash_to_field(value);
// Also: Poseidon4, Poseidon8

// Keccak & SHA3 (EVM-compatible, for cross-chain use)
let h: [bool; 256] = Keccak256::hash_to_bits(value);
// Also: Keccak384, Keccak512, SHA3_256, SHA3_384, SHA3_512

// Raw variants (no type metadata in hash input)
let h: field = Poseidon2::hash_to_field_raw(value);
let h: [bool; 256] = Keccak256::hash_to_bits_raw(value);
```

### Commit Functions
```leo
// Pedersen commitment (with scalar blinding factor)
let c: group = Pedersen64::commit_to_group(value, 1scalar);
let c: field = BHP256::commit_to_field(value, randomizer);
```

### Randomization
```leo
// Generate random values (only in finalize/async functions)
let r: u32 = ChaCha::rand_u32();
let r: field = ChaCha::rand_field();
let r: bool = ChaCha::rand_bool();
// ChaCha::rand_<type>() for any primitive type
```

### Signature Verification
```leo
// Schnorr signature (native Aleo)
let valid: bool = signature::verify(sig, addr, message);

// ECDSA (for Ethereum interop)
let valid: bool = ECDSA::verify_keccak256(sig, addr, msg);
let valid: bool = ECDSA::verify_keccak256_eth(sig, eth_addr, msg);  // Ethereum address
let valid: bool = ECDSA::verify_digest(sig, addr, digest);           // prehashed
let valid: bool = ECDSA::verify_digest_eth(sig, eth_addr, digest);   // Ethereum + prehashed

// Raw variants (no type metadata)
let valid: bool = ECDSA::verify_keccak256_raw(sig, addr, msg);
```

### Bit Serialization
```leo
// Standard serialization (includes type metadata)
let bits: [bool; 58] = Serialize::to_bits(value);

// Raw serialization (no metadata, just raw bits)
let raw_bits: [bool; 32] = Serialize::to_bits_raw(value);
```

## Context-Dependent Expressions

### Transition-only
```leo
self.caller    // address — who called this transition
self.signer    // address — who signed the transaction (origin)
```

### Finalize-only
```leo
block.height     // u32 — current block height
block.timestamp  // i64 — current block timestamp
```

### Constructor-only (program metadata)
```leo
self.edition        // u16 — current program edition/version
self.program_owner  // address — who deployed the program
self.checksum       // field — hash of the new program code
self.address        // address — the program's own address
```

## Annotations
- `@noupgrade` — prevents program upgrades after deployment
- `@test` — marks a transition as a test (outside program block)
- `@should_fail` — marks a test expected to fail (assertion/arithmetic error)
- `@admin` — admin-controlled upgrade constructor
- `@checksum` — checksum-gated upgrade constructor
- `@custom` — custom logic upgrade constructor

## Reserved Words & Identifiers

### Keywords (cannot be used as identifiers anywhere)
**Literals**: `true`, `false`, `none`
**Types**: `address`, `bool`, `field`, `group`, `scalar`, `signature`, `string`, `record`, `Final`, `i8`, `i16`, `i32`, `i64`, `i128`, `u8`, `u16`, `u32`, `u64`, `u128`
**Control flow**: `if`, `else`, `for`, `in`, `return`
**Declarations**: `let`, `const`, `constant`, `final`, `fn`, `Fn`, `struct`, `constructor`, `interface`
**Program structure**: `program`, `import`, `mapping`, `storage`, `network`, `aleo`, `script`, `block`
**Visibility**: `public`, `private`, `as`, `self`, `assert`, `assert_eq`, `assert_neq`

### Reserved struct/record member names
- `value` — reserved in structs AND records (cannot be used as a field name)
- `owner` — reserved in structs only (allowed in records, where it's the owner field)

### Aleo Instructions reserved words (also blocked)
These come from snarkVM's `KEYWORDS` and `RESTRICTED_KEYWORDS`:
`input`, `output`, `key`, `value`, `finalize`, `transition`, `function`, `closure`, `async`

### Additional restrictions
- Identifiers max 31 characters (EPAR0370044)
- No underscore-prefixed identifiers (`_foo` is invalid)
- Program names cannot contain "aleo" as a substring (except the `.aleo` suffix)
- No identifier can match a type name (`u32`, `field`, `bool`, etc.)

### Safe naming tips
- Use descriptive names: `amt` not `value`, `holder` not `owner`, `idx` not `key`
- For struct fields that would naturally be `value` or `owner`, use alternatives: `amount`, `data`, `content`, `holder`, `creator`, `admin`
