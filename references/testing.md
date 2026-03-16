# Testing Leo Programs

## Built-in Test Framework

Leo has a built-in test framework using the `@test` annotation.

### Running Tests
```bash
leo test                        # Run all tests
leo test --filter test_name     # Run specific test
```

### Test File Structure

Tests live in a `tests/` directory as separate `.leo` files. Each test file:
1. Imports the program under test
2. Wraps tests in a `program test_name.aleo { }` block
3. Uses `@test` annotation on transitions or scripts

```
my_program/
├── src/
│   └── main.leo              # Program source
└── tests/
    └── test_my_program.leo   # Test file
```

### Critical: Choosing Between `transition` and `script` Tests

**This is the most common source of test compilation errors.** Use this decision tree:

| Scenario | Test Type | Why |
|----------|-----------|-----|
| ALL called functions are pure transitions (no `finalize` block) | `transition` | No async/state operations needed |
| ANY called function is async (has a `finalize` block / returns a `Future`) | `script` | Futures can only be awaited in scripts |

**In practice, most tests should be `script`** since most real-world programs use async transitions with finalize blocks.

If you use a `transition` test to call an async function, you will get:
```
Error: "Function must contain a finalize block, since it calls X"
```

The fix is to change `transition` to `script`.

### Critical: Program Block Must Have At Least One Transition

Even if ALL your tests are scripts, the program block **must** contain at least one transition. Without it you get:
```
Error: ETYC0372083: A program must have at least one transition function
```

### Critical: Constructor Required (ConsensusVersion V9+)

ALL program blocks (including test programs) **must** include a constructor. Without it you get:
```
a new program after `ConsensusVersion::V9` must contain a constructor
```

The complete minimal test program structure requires both:
```leo
import my_program.aleo;

program test_my_program.aleo {
    @noupgrade
    async constructor() {}

    // Required: program must have at least one transition
    transition noop() {}

    @test
    script test_something() { /* ... */ }
}
```

### Critical: Use Valid Aleo Addresses

Fabricated/made-up addresses will fail with `EPAR0370001`. Always generate real test addresses:

```bash
leo account new
# Outputs a valid address like:
# aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5
```

Generate 2-3 addresses before writing tests and reuse them throughout.

### Critical: No Underscore-Prefixed Identifiers

Leo does **not** allow underscore-prefixed identifiers (e.g., `_f`, `_unused`). This is invalid:
```leo
let (_token, _f): (...) = ...;  // INVALID
```
Use regular names like `f1`, `f2`, `token1`, etc.

### Writing Tests

#### Pure Transition Tests

For programs with only pure transitions (no finalize):

```leo
// tests/test_my_program.leo
import my_program.aleo;

program test_my_program.aleo {
    @noupgrade
    async constructor() {}

    @test
    transition test_add() {
        let result: u32 = my_program.aleo/add(1u32, 2u32);
        assert_eq(result, 3u32);
    }

    @test
    transition test_add_zero() {
        let result: u32 = my_program.aleo/add(0u32, 5u32);
        assert_eq(result, 5u32);
    }
}
```

#### Script Tests (async/finalize testing)

Use `script` instead of `transition` when calling any async function. **Every Future returned must be `.await()`-ed** before accessing results or reading mappings:

```leo
@test
script test_mint_public() {
    let fut: Future = my_token.aleo/mint_public(
        aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5,
        500u64
    );
    fut.await();  // REQUIRED: execute the finalize block
    let bal: u64 = Mapping::get(my_token.aleo/account, aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5);
    assert_eq(bal, 500u64);
}
```

Script tests can:
- Await futures (`fut.await()`)
- Read/write mappings directly (`Mapping::get`, `Mapping::set`)
- Generate random values (`ChaCha::rand_field()`)

### Testing Records

Record types from imported programs must use fully qualified names:
```leo
import my_token.aleo;

program test_my_token.aleo {
    @noupgrade
    async constructor() {}

    // Required: at least one transition in program block
    transition noop() {}

    @test
    script test_transfer() {
        let (token, f1): (my_token.aleo/Token, Future) = my_token.aleo/mint(
            aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5,
            100u64
        );
        f1.await();
        let (remaining, sent): (my_token.aleo/Token, my_token.aleo/Token) = my_token.aleo/transfer(
            token,
            aleo1prpwseltwgaw20hn8p84ev2vygxh37zfgw9jka05k2lslu7y658qn69q8h,
            30u64
        );
        assert_eq(remaining.amount, 70u64);
        assert_eq(sent.amount, 30u64);
    }
}
```

### Complete Working Example

This example compiles and passes all tests against a token program with `mint_private`, `mint_public`, and `transfer_private` transitions:

```leo
import my_private_token.aleo;

program test_token.aleo {
    @noupgrade
    async constructor() {}

    // Required: program must have at least one transition
    transition noop() {}

    @test
    script test_transfer_private() {
        let (token, f1): (my_private_token.aleo/Token, Future) = my_private_token.aleo/mint_private(
            aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5,
            100u64
        );
        f1.await();
        let (remaining, sent): (my_private_token.aleo/Token, my_private_token.aleo/Token) = my_private_token.aleo/transfer_private(
            token,
            aleo1prpwseltwgaw20hn8p84ev2vygxh37zfgw9jka05k2lslu7y658qn69q8h,
            30u64
        );
        assert_eq(remaining.amount, 70u64);
        assert_eq(sent.amount, 30u64);
    }

    @test
    script test_mint_public() {
        let fut: Future = my_private_token.aleo/mint_public(
            aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5,
            500u64
        );
        fut.await();
        let bal: u64 = Mapping::get(my_private_token.aleo/account, aleo1a5ytclpvj2zcl8r7mhgy0x3l7dlsqvuun5e0chd7n73vels2859qwztdu5);
        assert_eq(bal, 500u64);
    }
}
```

### Test Annotations
- `@test` -- marks a transition or script as a test
- `@should_fail` -- marks a test that is expected to fail (assertion/arithmetic failure)
- Tests are transitions or scripts that take no arguments and return nothing
- Tests call program functions using the fully qualified name: `program_name.aleo/function_name()`
- Tests use `assert`, `assert_eq`, `assert_neq` to verify results

### Testing Expected Failures
```leo
@test
@should_fail
transition test_overflow() {
    let result: u64 = my_program.aleo/subtract(5u64, 10u64);
    // This will underflow and fail -- @should_fail expects this
}
```

### Critical: `self.caller` is the Same Address in All Script Tests

In Leo script tests, **every transition call uses the same `self.caller`** — the test runner's address. This means:

- You **cannot** test multi-party flows where different roles (buyer, seller, arbiter) need different addresses
- Guards like `assert_eq(caller, admin)` will pass for ALL calls since the test runner IS every party
- Guards like `assert_neq(buyer, seller)` will **FAIL** because both are the test runner

**Workarounds:**

1. **Use `update_*` helper transitions** that set a role to `self.caller`:
```leo
// In the main program — allows seller to reassign arbiter
async transition update_arbiter(public escrow_id: field) -> Future {
    return finalize_update_arbiter(escrow_id, self.caller);
}
// In finalize: Mapping::set(escrow_arbiter, escrow_id, caller);
```
Then in the test, call `update_arbiter` to make the arbiter == test runner.

2. **Remove `assert_neq` guards** that prevent self-dealing (buyer != seller). These are nice-to-have but not security-critical — a user could use two wallets anyway.

3. **Accept that role-based authorization can't be fully tested** in unit tests. Use devnet for true multi-party integration testing.

**Example — testing dispute resolution:**
```leo
@test
script test_dispute() {
    let escrow_id: field = 1field;
    // List with any arbiter address
    let f1: Future = my_escrow.aleo/list_item(escrow_id, 500u64, some_addr, some_addr);
    f1.await();
    // Overwrite arbiter to self.caller so resolve_dispute works
    let f2: Future = my_escrow.aleo/update_arbiter(escrow_id);
    f2.await();
    // ... fund, deliver, dispute, resolve all work because self.caller == all roles
}
```

### Warning: `self.caller` as Record Owner (WTYC0372004)

When creating records in transitions, using `self.caller` as the owner triggers a warning:
```
Warning [WTYC0372004]: `self.caller` used as the owner of record
= `self.caller` may refer to a program address, which cannot spend records.
```

This is safe for direct user calls but will fail if the transition is called by another program (cross-program call). For cross-program compatible code, accept the owner as a parameter instead.

## Local Execution Testing

### Using `leo run`
```bash
# Test individual functions without deploying
leo run add 5u32 10u32
# Output: 15u32

leo run transfer "{owner: aleo1..., amount: 100u64}" aleo1receiver... 50u64
```

### Input Files
Create input files in `inputs/`:

```
// inputs/my_program.in
[add]
a: u32 = 5u32;
b: u32 = 10u32;
```

```bash
leo run add
```

## Devnet Testing

For testing async transitions with finalize (on-chain state), use a local devnet:

```bash
# Terminal 1: start devnet
leo devnode

# Terminal 2: deploy and execute
leo deploy --endpoint http://localhost:3030
leo execute add 5u32 10u32 --endpoint http://localhost:3030 --broadcast
```

This tests the full flow including:
- Transaction creation and proof generation
- Proof verification on-chain
- Finalize execution and mapping state changes

## Testing Best Practices

1. **Default to `script` tests**: most real programs use async transitions, so `script` is the safer default
2. **Always include a constructor and noop transition**: `@noupgrade async constructor() {}` is required (ConsensusVersion V9+), and `transition noop() {}` prevents ETYC0372083 when all tests are scripts
3. **Generate valid addresses first**: run `leo account new` 2-3 times before writing tests
4. **Await all futures immediately**: every Future from an async call must be `.await()`-ed before using results
5. **Test all transitions**: write at least one test per transition
6. **Test edge cases**: zero values, maximum values, boundary conditions
7. **Test record consumption**: verify that record inputs are properly consumed and new records are correct
8. **Test authorization**: verify that caller checks work (use `@should_fail` for unauthorized calls)
9. **Test hybrid flows**: if your program has private-to-public or public-to-private transitions, test the full cycle
10. **Use meaningful test names**: `test_transfer_insufficient_balance`, not `test_1`
11. **Use fully qualified types**: record types from imported programs need `program.aleo/Type` syntax
12. **No underscore prefixes**: use `f1`, `f2`, `token1` -- never `_f`, `_token`

## SDK Testing

For testing frontend integration:

```typescript
import { ProgramManager } from '@provablehq/sdk';

// Run program offline (no network needed)
const pm = new ProgramManager();
const account = new Account();
pm.setAccount(account);

const result = await pm.run(
    programSource,
    "add",
    ["5u32", "10u32"],
    false  // don't prove execution
);

const outputs = result.getOutputs();
// Verify outputs
```
