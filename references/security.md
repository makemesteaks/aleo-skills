# Security Checklist

## ZK-Specific Vulnerabilities

### 1. Information Leakage via Public Inputs/Outputs
**Risk**: marking inputs or outputs as `public` reveals them on-chain.

```leo
// BAD: reveals the amount publicly
async transition transfer(public receiver: address, public amount: u64) -> Future { ... }

// BETTER: keep amount private when possible
async transition transfer(receiver: address, amount: u64) -> (Token, Future) { ... }
```

**Rule**: only use `public` when the data MUST be visible (e.g., mapping keys, public registry entries).

### 2. Record Front-Running
**Risk**: if a transition consumes a record and the transaction is visible in the mempool, an attacker could submit a competing transaction.

**Mitigation**: records are encrypted — only the owner can see them. But if the program logic is predictable (e.g., first-come-first-served), timing attacks are still possible.

### 3. Mapping Race Conditions
**Risk**: multiple transactions reading/writing the same mapping key can conflict.

```leo
// If two users call this simultaneously with the same key,
// one transaction will succeed and one will revert
async function finalize_bid(public auction_id: field, public amount: u64) {
    let current: u64 = Mapping::get_or_use(bids, auction_id, 0u64);
    Mapping::set(bids, auction_id, current + amount);
}
```

**Mitigation**: design finalize logic to be commutative where possible (additions are safe, replacements are not).

### 4. Overflow/Underflow
**Risk**: arithmetic overflow causes proof failure and transaction revert.

**Good news**: Leo arithmetic is checked by default. `a - b` where `b > a` on unsigned types will revert the transaction (proof fails).

**Still check**: ensure your logic handles the revert gracefully in the frontend.

### 5. Missing Caller Verification
**Risk**: any address can call any public transition.

```leo
// BAD: anyone can mint tokens
transition mint(receiver: address, amount: u64) -> Token {
    return Token { owner: receiver, amount: amount };
}

// GOOD: restrict to admin
transition mint(receiver: address, amount: u64) -> Token {
    assert_eq(self.caller, aleo1admin...);
    return Token { owner: receiver, amount: amount };
}
```

### 6. Record Ownership Bypass
**Risk**: creating records with incorrect owner field.

```leo
// BAD: allows caller to create records owned by anyone
transition create(owner: address) -> Token {
    return Token { owner: owner, amount: 1000u64 };
}

// BETTER: restrict who can create, or use self.caller
transition create() -> Token {
    return Token { owner: self.caller, amount: 1000u64 };
}
```

### 7. Finalize Failure Denial of Service
**Risk**: if finalize always fails for a user (e.g., missing mapping entry with `get` instead of `get_or_use`), they can't use the program.

```leo
// BAD: fails if user has no balance entry
async function finalize_transfer(sender: address, amount: u64) {
    let bal: u64 = Mapping::get(account, sender);  // FAILS if no entry
    Mapping::set(account, sender, bal - amount);
}

// GOOD: use get_or_use with sensible default
async function finalize_transfer(sender: address, amount: u64) {
    let bal: u64 = Mapping::get_or_use(account, sender, 0u64);
    Mapping::set(account, sender, bal - amount);
}
```

### 8. Transaction Pattern Analysis
**Risk**: even with private records, transaction patterns (timing, frequency, program calls) can leak information about user behavior.

**Mitigation**: consider dummy transactions, batching, or time-delayed submissions for high-privacy applications.

## Security Review Checklist

### Authorization
- [ ] All privileged transitions check `self.caller` or `self.signer`
- [ ] Record creation assigns correct `owner`
- [ ] Admin addresses are hardcoded (not passed as parameters)

### State Management
- [ ] Use `Mapping::get_or_use` (not `get`) unless you want to fail on missing keys
- [ ] Mapping operations are commutative where possible
- [ ] No unintended public state exposure

### Privacy
- [ ] Minimum necessary inputs marked as `public`
- [ ] Sensitive data stored in records, not mappings
- [ ] Mapping keys are hashed when they could reveal identity
- [ ] Transaction patterns don't leak user behavior

### Arithmetic
- [ ] Overflow/underflow cases handled (Leo checks by default, but UX matters)
- [ ] Division by zero cases impossible
- [ ] Loop bounds are correct and sufficient

### Program Limits
- [ ] Program size under 100 KB compiled
- [ ] Transaction size under 128 KB
- [ ] Mapping count under 31
- [ ] Function count under 31

### Deployment
- [ ] `@noupgrade` used if program should be immutable
- [ ] Constructor is correct (upgrade/no-upgrade decision is intentional)
- [ ] Program name is unique and reserved on-chain
