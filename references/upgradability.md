# Program Upgradability

## Overview

Leo programs can be upgraded after deployment. The upgrade system uses a **constructor** function to control who/how upgrades happen. By default, programs are upgradable by the deployer.

## Upgrade Modes

### 1. `@noupgrade` — Immutable
```leo
program my_token.aleo {
    @noupgrade
    async constructor() {}

    transition transfer(...) { ... }
}
```
The program can NEVER be changed after deployment. Use for trustless protocols where immutability is a feature.

### 2. `@admin` — Admin-Controlled (Default Behavior)
```leo
program my_token.aleo {
    // The deployer's address is set as admin automatically
    // Only the admin can upgrade the program

    transition transfer(...) { ... }
}
```
If no constructor is specified, the deployer becomes the admin by default. The admin can push new versions.

### 3. `@checksum` — Content-Hash Gated
```leo
program my_token.aleo {
    @checksum
    async constructor() {}
}
```
Upgrades require providing the checksum of the new program version. Useful for pre-committing to specific upgrade paths.

### 4. `@custom` — Custom Logic
```leo
program my_token.aleo {
    mapping upgrade_votes: u8 => u64;

    @custom
    async constructor() -> Future {
        return finalize_constructor();
    }

    async function finalize_constructor() {
        let votes: u64 = Mapping::get_or_use(upgrade_votes, 0u8, 0u64);
        assert(votes >= 100u64);  // Require 100 votes to upgrade
    }
}
```
Arbitrary on-chain logic gates the upgrade. Use for governance-controlled upgrades.

## Constructor Metadata

Inside constructors, you can access:

```leo
self.edition        // u16 — current edition/version number (starts at 0)
self.program_owner  // address — current program admin
self.checksum       // field — hash of the new program code
```

## What Can Be Upgraded

| Component | Upgradable? |
|-----------|------------|
| Transition logic (body) | Yes |
| Finalize logic (body) | Yes |
| New transitions | Yes |
| New mappings | Yes |
| Transition signatures | No — must keep same name, inputs, outputs |
| Record definitions | No — must keep same fields and types |
| Struct definitions | No — must keep same fields and types |
| Mapping key/value types | No |
| Program name | No |

**Key rule**: the public interface (signatures, types) is immutable. Only internal logic changes.

## Upgrade Patterns

### Time-Locked Upgrade
```leo
mapping upgrade_after: u8 => u32;

@custom
async constructor() -> Future {
    return finalize_constructor();
}

async function finalize_constructor() {
    let unlock: u32 = Mapping::get_or_use(upgrade_after, 0u8, 0u32);
    assert(block.height >= unlock);
}
```

### Governance-Gated Upgrade
```leo
mapping approval_count: u8 => u64;

@custom
async constructor() -> Future {
    return finalize_constructor();
}

async function finalize_constructor() {
    let approvals: u64 = Mapping::get_or_use(approval_count, 0u8, 0u64);
    assert(approvals >= 3u64);  // Requires 3 approvals
    Mapping::set(approval_count, 0u8, 0u64);  // Reset for next upgrade
}
```

### Admin Transfer
```leo
// Use a transition to propose new admin, then upgrade with the new admin
transition propose_admin(new_admin: address) {
    assert_eq(self.caller, aleo1current_admin...);
    // Store proposed admin in mapping via finalize
}
```

## ABI (Application Binary Interface)

`leo build` automatically generates an ABI JSON file in `build/`. The ABI describes:

```json
{
  "program": "my_token.aleo",
  "structs": [...],
  "records": [...],
  "mappings": [...],
  "transitions": [
    {
      "name": "transfer",
      "inputs": [
        { "name": "to", "type": "address", "visibility": "private" },
        { "name": "amount", "type": "u64", "visibility": "private" }
      ],
      "outputs": [
        { "type": "Token", "visibility": "record" }
      ]
    }
  ]
}
```

### Using the ABI
- The SDK uses ABI to encode/decode transition inputs and outputs
- Frontend code can read the ABI to dynamically build transaction forms
- ABI is generated automatically — no extra flags needed

### Type Lowering
The ABI maps Leo types to Aleo VM types:
- `bool` → `boolean`
- `u8`..`u128`, `i8`..`i128` → same names
- `field`, `group`, `scalar`, `address` → same names
- `struct Foo { x: u32, y: u64 }` → struct definition with fields
- `record Token { owner: address, amount: u64 }` → record definition
- `Option<T>` / `T?` → lowered to struct `{ is_some: bool, val: T }`
- Tuples → expanded to individual outputs

## Security Considerations

- Choose `@noupgrade` for programs that manage user funds or trust-critical state where immutability is expected
- For upgradable programs, clearly communicate the upgrade policy to users
- Time-lock upgrades to give users time to exit if they disagree with changes
- Consider governance-gated upgrades for community-owned programs
- The constructor runs on EVERY upgrade — ensure it can't be bypassed
- Legacy programs (deployed before the upgrade framework) are immutable by default
