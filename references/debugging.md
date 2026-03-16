# Debugging Leo Programs

## Leo Debugger

Leo has a built-in interactive debugger invoked with `leo debug`.

### Starting the Debugger
```bash
# Debug a specific transition
leo debug <transition_name> <input_1> <input_2> ...

# Example
leo debug main 5u32 10u32

# With TUI (graphical terminal interface)
leo debug main 5u32 10u32 --tui
```

### REPL Commands

| Command | Short | Description |
|---------|-------|-------------|
| `step` | `s` | Step to next statement |
| `step into` | `si` | Step into function call |
| `step out` | `so` | Step out of current function |
| `run` | `r` | Run until next breakpoint or end |
| `breakpoint <line>` | `b <line>` | Set breakpoint at line number |
| `delete <n>` | `d <n>` | Delete breakpoint |
| `print <expr>` | `p <expr>` | Evaluate and print expression |
| `watch <expr>` | `w <expr>` | Watch expression (prints on each step) |
| `into <program>` | — | Set namespace to another program |
| `quit` | `q` | Exit debugger |

### Debugging Workflow

```bash
$ leo debug main 5u32 10u32

# Step through execution
> step
  → let sum: u32 = a + b;   // sum = 15u32

# Print variable values
> print sum
  15u32

# Set a breakpoint
> breakpoint 12
  Breakpoint set at line 12

# Run to breakpoint
> run

# Watch a variable across steps
> watch result
```

### Debugging Imported Programs
```bash
# Switch namespace to debug an imported program
> into other_program.aleo

# Then step/print as normal within that program's context
> step
> print state
```

### TUI Mode
```bash
leo debug main 5u32 10u32 --tui
```
Provides a terminal UI with:
- Source code display with current line highlighted
- Variable watch panel
- Breakpoint indicators
- Step controls

## Debugging Strategies

### 1. Print-Style Debugging with Assertions
Since Leo has no `print` statement in programs, use assertions to verify intermediate values:
```leo
transition process(a: u32, b: u32) -> u32 {
    let intermediate: u32 = a * b;
    assert_eq(intermediate, 50u32);  // Will fail with proof error if wrong
    return intermediate + 1u32;
}
```

### 2. Test-Driven Debugging
Write focused `@test` transitions to isolate the problem:
```leo
@test
transition test_specific_case() {
    // Reproduce the exact failing scenario
    let result: u32 = my_program.aleo/process(5u32, 10u32);
    assert_eq(result, 51u32);
}
```

```bash
leo test --filter test_specific_case
```

### 3. Local Execution
Use `leo run` to execute transitions locally and see outputs without deploying:
```bash
leo run process 5u32 10u32
# Shows the return value immediately
```

### 4. Incremental Building
When debugging complex programs:
1. Comment out the complex logic
2. Return a known value
3. Gradually re-enable logic, testing after each change
4. The point where it breaks reveals the bug

### 5. Finalize Debugging
Finalize blocks can't be debugged with `leo debug` (they run on-chain). Use devnet:
```bash
# Terminal 1
leo devnode

# Terminal 2
leo deploy --endpoint http://localhost:3030
leo execute my_function args --endpoint http://localhost:3030 --broadcast
```

Check devnet logs for finalize execution details and failures.

### 6. Type Narrowing
Many bugs come from type issues. Verify types explicitly:
```leo
let a: u64 = value;           // Will fail at compile time if value isn't u64
let b: u64 = value as u64;    // Explicit cast
```

## Common Debugging Patterns

### "My transaction reverts but I don't know why"
1. Check for arithmetic overflow/underflow (especially `a - b` where `b > a` on unsigned types)
2. Check for `Mapping::get` on non-existent keys (use `get_or_use`)
3. Check `assert` / `assert_eq` conditions
4. Check `block.height` requirements in finalize
5. Use `leo debug` to step through the transition logic

### "My record has wrong values"
1. Write a `@test` that mints/creates the record and checks each field
2. Verify the owner field is set correctly (usually `self.caller`)
3. Check arithmetic in field calculations

### "Cross-program call fails"
1. Verify the imported program is deployed (if `location: network`)
2. Check that type names match exactly (e.g., `other.aleo/RecordType`)
3. Verify argument types match the imported transition's signature
4. Use `> into other_program.aleo` in the debugger to step into the call
