# Program Composition

## Importing Programs

Leo programs can import and call other deployed programs:

```leo
import board.aleo;
import move.aleo;
import verify.aleo;

program battleship.aleo {
    transition initialize_board(carrier: u64) -> board.aleo/BoardState {
        let valid: bool = verify.aleo/validate_ship(carrier, 5u64, 31u64, 4311810305u64);
        assert(valid);
        let state: board.aleo/BoardState = board.aleo/new_board_state(carrier, self.caller);
        return state;
    }
}
```

### Import Syntax
```leo
import other_program.aleo;
```

### Calling Imported Functions
```leo
// Call a transition from another program
let result: other_program.aleo/RecordType = other_program.aleo/function_name(args);

// Access types from imported programs
let state: board.aleo/BoardState = ...;
```

## Dependencies in program.json

```json
{
    "program": "battleship.aleo",
    "version": "0.1.0",
    "description": "A battleship game",
    "license": "MIT",
    "dependencies": [
        {
            "name": "board.aleo",
            "location": "network",
            "network": "testnet"
        },
        {
            "name": "move.aleo",
            "location": "network",
            "network": "testnet"
        },
        {
            "name": "verify.aleo",
            "location": "local",
            "path": "../verify"
        }
    ]
}
```

### Dependency Locations
- `"location": "network"` — fetch from the Aleo network (must already be deployed)
- `"location": "local"` — reference a local program directory

### Adding Dependencies
```bash
leo add <program_name>                    # Add from network
leo add <program_name> --local <path>     # Add from local path
leo add <program_name> --network testnet  # Add from specific network
```

## Cross-Program Calls

### Rules
1. You can call transitions from imported programs
2. You can use types (records, structs) defined in imported programs
3. Cross-program calls create nested proofs — each call adds to the transaction size
4. Maximum import depth: 64
5. Maximum imports per program: 64
6. Maximum call depth: 31

### Returning Imported Types
```leo
import token.aleo;

program exchange.aleo {
    // This transition returns a record type from the imported program
    transition swap(input_token: token.aleo/Token) -> token.aleo/Token {
        // ... swap logic
    }
}
```

## Architecture Patterns

### Modular Program Design
Split complex applications into focused programs:

```
my_dapp/
├── token.aleo         # Token logic (mint, transfer)
├── exchange.aleo      # Exchange logic (swap, provide liquidity)
├── governance.aleo    # Governance (proposals, voting)
└── main.aleo          # Entry point, orchestrates the above
```

### Core Program (Reusable)
Deploy reusable programs that others can import:
```leo
program utils.aleo {
    // Reusable utility functions
    transition hash_pair(a: field, b: field) -> field {
        return BHP256::hash_to_field(a + b);
    }
}
```

### Application Program (Imports Core)
```leo
import utils.aleo;

program my_app.aleo {
    transition process(a: field, b: field) -> field {
        return utils.aleo/hash_pair(a, b);
    }
}
```

## Deployment Order

When deploying multi-program applications:

1. Deploy dependency programs first (deepest dependencies first)
2. Deploy the main program last
3. Each program deployment is a separate transaction with its own fee

```bash
# Deploy in dependency order
cd verify && leo deploy
cd ../board && leo deploy
cd ../move && leo deploy
cd ../battleship && leo deploy  # depends on verify, board, move
```

## Program Limits

- Max imports per program: 64
- Max import depth: 64
- Max call depth: 31
- Each cross-program call adds to transaction size (128 KB max)
