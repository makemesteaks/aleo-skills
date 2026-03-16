# Common Errors & Fixes

## Error Code Format

Leo errors follow the pattern: `E{PREFIX}037{CODE}`

| Category | Prefix | Description |
|----------|--------|-------------|
| Parser | PAR | Syntax and tokenization errors |
| AST | AST | Abstract syntax tree errors |
| Compiler | CMP | Semantic and codegen errors |
| CLI | CLI | Command-line interface errors |
| Type Checker | — | Type mismatch and inference errors |

## Compiler Errors

### Missing Type Suffix
```
Error: expected type suffix on literal
```
```leo
// BAD
let x = 5;

// GOOD — Leo requires explicit type suffixes
let x: u32 = 5u32;
```

### Type Mismatch
```
Error: expected 'u64', found 'u32'
```
Leo has no implicit type conversion. Cast explicitly:
```leo
let a: u32 = 5u32;
let b: u64 = a as u64;
```

### Unbounded Loop
```
Error: loop bound must be a constant
```
```leo
// BAD — loop bounds must be compile-time constants
for i: u32 in 0u32..n { ... }

// GOOD
for i: u32 in 0u32..10u32 { ... }
```

### Mapping Access in Transition
```
Error: mappings can only be accessed in finalize blocks
```
```leo
// BAD — can't read mappings in transitions
transition check(key: address) {
    let val: u64 = Mapping::get(balances, key);  // ERROR
}

// GOOD — use async transition + finalize
async transition check(key: address) -> Future {
    return finalize_check(key);
}
async function finalize_check(key: address) {
    let val: u64 = Mapping::get_or_use(balances, key, 0u64);
}
```

### Self.caller in Finalize
```
Error: 'self.caller' is not available in finalize
```
```leo
// BAD
async function finalize_action() {
    let caller: address = self.caller;  // ERROR
}

// GOOD — pass caller from transition
async transition action() -> Future {
    return finalize_action(self.caller);
}
async function finalize_action(caller: address) {
    // use caller parameter
}
```

### Record Field Not Found
```
Error: record 'Token' has no field 'balance'
```
Record fields are defined in the record declaration. Check the field name matches exactly.

### Missing Return Type
```
Error: async transition must return 'Future'
```
```leo
// BAD
async transition increment() {
    return finalize_increment();
}

// GOOD — must declare Future return type
async transition increment() -> Future {
    return finalize_increment();
}
```

### Tuple Return with Future
```
Error: expected return type '(Token, Future)'
```
When returning both a record and a finalize call:
```leo
async transition mint(amount: u64) -> (Token, Future) {
    let token: Token = Token { owner: self.caller, amount: amount };
    return (token, finalize_mint(amount));
}
```

### Finalize Requires Finalize Block
```
Error: Function must contain a finalize block, since it calls X
```
A `transition` that calls an async transition (which has a finalize block) must itself handle the finalize chain:
```leo
// BAD — transition test calls async transition without finalize
transition test_mint() {
    let result: (Token, Future) = mint(100u64);
}

// GOOD — use script mode and await the Future
@test
script test_mint() {
    let (token, f): (Token, Future) = mint(100u64);
    f.await();
}
```

### Identifier Too Long
```
EPAR0370044: Identifier too long (N bytes; max 31)
```
Function and variable names cannot exceed 31 characters:
```leo
// BAD — 35 characters
async function finalize_transfer_private_to_public(...) { ... }

// GOOD — shortened to fit
async function finalize_priv_to_pub(...) { ... }
```
**Tip:** Finalize function names are auto-prefixed from the transition name. Count characters carefully.

### Underscore-Prefixed Identifier
```
EPAR0370005: expected an identifier -- found '_f'
```
Leo does not allow underscore-prefixed identifiers (unlike Rust's `_` convention):
```leo
// BAD — underscore prefix not allowed
let (_f, token): (Future, Token) = ...;

// GOOD — use regular short names
let (f1, token): (Future, Token) = ...;
```

### Invalid Address Literal
```
EPAR0370001: invalid address literal
```
The address string is fabricated and fails checksum validation. Never make up address values:
```bash
# GOOD — generate a valid address for testing
leo account new
```
Always use `leo account new` to produce test addresses.

### Unexpected '@' Outside Tests Directory
```
EPAR0370005: expected 'import', 'program' -- found '@'
```
`@test` annotations placed directly in `src/main.leo` after the program block are not valid:
```leo
// BAD — tests inside src/main.leo
program my_app.aleo { ... }
@test
script test_foo() { ... }  // ERROR

// GOOD — tests in tests/test_app.leo
import my_app.aleo;
program test_app.aleo {
    @test
    script test_foo() { ... }
}
```

### Program Must Have a Transition
```
ETYC0372083: A program must have at least one transition function
```
A test program block that contains only `script` tests and no transitions will fail:
```leo
// BAD — no transitions
program test_app.aleo {
    @test
    script test_foo() { ... }
}

// GOOD — add a dummy transition
program test_app.aleo {
    transition noop() {}

    @test
    script test_foo() { ... }
}
```

### Constructor Required (ConsensusVersion V9+)
```
a new program after `ConsensusVersion::V9` must contain a constructor
```
**Cause**: All programs (including test programs) must include a constructor after ConsensusVersion V9.
```leo
// BAD — no constructor
program my_program.aleo {
    transition foo() {}
}

// GOOD — add constructor
program my_program.aleo {
    @noupgrade
    async constructor() {}

    transition foo() {}
}
```

### Reserved Struct Member Name
```
Error [ENV03711000]: `value` is an invalid struct member name.
```
**Cause**: Certain names are reserved and cannot be used as struct/record field names.

**Reserved in structs AND records**: `value`, `input`, `output`, `key`, `finalize`, `transition`, `function`, `closure`, `async`, and all Leo keywords (`self`, `program`, `mapping`, `record`, etc.)

**Reserved in structs only** (allowed in records): `owner`

```leo
// BAD
struct Data { value: u32, owner: address, key: field }

// GOOD — use alternatives
struct Data { amount: u32, holder: address, idx: field }
```

### self.caller as Record Owner Warning (WTYC0372004)
```
Warning [WTYC0372004]: `self.caller` used as the owner of record
= `self.caller` may refer to a program address, which cannot spend records.
```
**Cause**: Using `self.caller` as the `owner` field when creating a record. If the transition is called by another program (cross-program call), `self.caller` is the calling program's address, which cannot spend records.

**Safe when**: The transition is only called directly by users (not by other programs).

**Fix for cross-program**: Accept the owner as a parameter instead:
```leo
// Instead of: owner: self.caller
transition buy_ticket(recipient: address, ...) -> Ticket {
    return Ticket { owner: recipient, ... };
}
```

### Conditional Reassignment in Async (ETYC0372109)
```
Error [ETYC0372109]: Cannot re-assign to variable from conditional scope in async function
```
**Cause**: ZK circuits require deterministic execution. Variables can't be reassigned inside `if/else` in async (finalize) functions.

```leo
// BAD — conditional reassignment in async
async function finalize_claim(...) {
    let shares: u64 = 0u64;
    if state == 1u8 {
        shares = yes_bal;  // ERROR
    } else {
        shares = no_bal;
    }
}

// GOOD — use ternary operator
async function finalize_claim(...) {
    let shares: u64 = state == 1u8 ? yes_bal : no_bal;
}
```

### self.caller Identity in Script Tests
```
assert failure: aleo1abc... == aleo1abc... (looks identical but fails)
assert failure: aleo1abc... != aleo1xyz... (different addresses)
```
**Cause**: In `leo test` script tests, `self.caller` is always the **test runner's ephemeral address** for every transition call. This means:
- `assert_neq(buyer, seller)` fails because both are the test runner
- `assert_eq(caller, arbiter)` fails if arbiter was set to a different address

**Fix**: See Testing guide → "self.caller is the Same Address in All Script Tests" for workarounds.

## Deployment Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Insufficient balance" | Not enough credits for fees | Fund account via faucet or transfer |
| "Program already exists" | Program name taken on-chain | Choose a different program name |
| "Transaction too large" | Exceeds 128 KB limit | Split into smaller programs |
| "Fee too low" | Priority fee insufficient | Increase `--priority-fee` |
| "Build failed" | Compilation errors | Run `leo build` and fix errors first |

## WASM / SDK Errors

### "SharedArrayBuffer is not defined"
WASM proof generation requires specific headers:
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```
Add to your dev server config (Vite, Next.js, etc.).

### "Module not found: @provablehq/sdk"
```bash
npm install @provablehq/sdk@latest
```
Must use ES modules — add `"type": "module"` to package.json or use `.mjs` extensions.

### "Cannot use import statement outside a module"
The SDK is ESM-only. Ensure your bundler supports ES modules. For Vite:
```js
// vite.config.js
export default defineConfig({
  optimizeDeps: {
    exclude: ['@provablehq/sdk']
  }
});
```

### Web Worker Issues
WASM must run in a Web Worker (not main thread in browsers). Use the comlink pattern:
```js
// worker.js — runs WASM
import { ProgramManager } from '@provablehq/sdk';
// ...

// App.jsx — calls worker
const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
```

## Runtime Errors

### "Proof verification failed"
- Assertion failed in the program (assert, assert_eq)
- Arithmetic overflow/underflow
- Missing mapping key (used `get` instead of `get_or_use`)

The entire transaction reverts — including record changes from the transition.

### "Record already spent"
Records are UTXOs — once consumed in a transaction, they cannot be reused. Fetch fresh records from the network before building a new transaction.

### "Finalize failed"
On-chain finalize block failed. Common causes:
- `Mapping::get` on non-existent key (use `get_or_use`)
- Arithmetic overflow in mapping update
- `assert` or `assert_eq` failure
- `block.height` check not met

## Debugging Tips

1. **Use `leo run` first** — test locally before deploying
2. **Use `leo test`** — write `@test` transitions to catch issues early
3. **Check types** — most errors are type mismatches or missing suffixes
4. **Use `leo debug`** — step through execution interactively
5. **Read the full error** — Leo error messages include the file, line, and column
