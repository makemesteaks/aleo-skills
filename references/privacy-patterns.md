# Privacy Design Patterns

## The Core Decision: Records vs Mappings

Every piece of state in an Aleo program is either:
- **Private (record)**: encrypted on-chain, only owner can see/spend it. UTXO model — consumed on use.
- **Public (mapping)**: visible to everyone, persistent key-value store. Account model — updated in place.

### When to Use Records (Private)
- Token balances that should be hidden
- Votes that should be anonymous
- Bids in an auction
- Personal data (identity, medical, financial)
- Tickets, NFTs, credentials

### When to Use Mappings (Public)
- Total supply counters
- Vote tallies (aggregate results)
- Program configuration
- Public registries
- Leaderboards, public scores

### When to Use Both (Hybrid)
Most real applications use both:
- **Private ownership** via records + **public aggregates** via mappings
- Example: private token balances (records) + public total supply (mapping)

## Pattern 1: Private Token

The simplest privacy pattern — all balances are private records.

```leo
record Token {
    owner: address,
    amount: u64,
}

transition mint(receiver: address, amount: u64) -> Token {
    return Token { owner: receiver, amount: amount };
}

transition transfer(token: Token, to: address, amount: u64) -> (Token, Token) {
    let change: u64 = token.amount - amount;
    return (
        Token { owner: token.owner, amount: change },
        Token { owner: to, amount: amount }
    );
}
```

**Privacy**: sender, receiver, and amount are all hidden. Only the record owners know the values.

## Pattern 2: Private Voting

Voter identity is hidden, but vote counts are public.

```leo
record Ticket {
    owner: address,
    pid: field,     // proposal ID
}

mapping agree_votes: field => u64;
mapping disagree_votes: field => u64;

// Issue a private ticket — only the voter knows they have it
async transition new_ticket(public pid: field, public voter: address) -> (Ticket, Future) {
    return (Ticket { owner: voter, pid }, finalize_new_ticket(pid));
}

// Vote privately — the ticket is consumed, vote is counted publicly
async transition agree(ticket: Ticket) -> Future {
    return finalize_agree(ticket.pid);
}

async function finalize_agree(public pid: field) {
    let current: u64 = Mapping::get_or_use(agree_votes, pid, 0u64);
    Mapping::set(agree_votes, pid, current + 1u64);
}
```

**Privacy**: no one can link a vote to a voter. The ticket is consumed privately, and only the aggregate count is updated publicly.

## Pattern 3: Sealed-Bid Auction

Bids are private records. Only the auctioneer can resolve them.

```leo
record Bid {
    owner: address,     // auctioneer (receives the bid record)
    bidder: address,    // who placed the bid
    amount: u64,
    is_winner: bool,
}

// Bidder places a bid — record goes to auctioneer
transition place_bid(bidder: address, amount: u64) -> Bid {
    assert_eq(self.caller, bidder);
    return Bid {
        owner: aleo1auctioneer...,
        bidder: bidder,
        amount: amount,
        is_winner: false,
    };
}

// Auctioneer resolves bids (pairwise comparison)
transition resolve(first: Bid, second: Bid) -> Bid {
    assert_eq(self.caller, aleo1auctioneer...);
    if (first.amount >= second.amount) {
        return first;
    } else {
        return second;
    }
}

// Return winning bid to the winner
transition finish(bid: Bid) -> Bid {
    assert_eq(self.caller, aleo1auctioneer...);
    return Bid {
        owner: bid.bidder,  // transfer ownership to winner
        bidder: bid.bidder,
        amount: bid.amount,
        is_winner: true,
    };
}
```

**Privacy**: bidders don't see each other's bids. Only the auctioneer sees individual bids, and only the winning bid amount is revealed.

## Pattern 4: Hybrid Token (Private + Public)

The full-featured token pattern supporting four transfer modes:
1. **Public → Public**: both sides visible (like ERC-20)
2. **Private → Private**: both sides hidden
3. **Private → Public**: withdraw from private into public balance
4. **Public → Private**: shield public balance into private record

See `leo-programs.md` for the complete implementation.

## Pattern 5: Privacy-Preserving Public Storage

When you need public storage but want to obscure the owner:
```leo
mapping balances: field => u64;  // key is a hash, not an address

async transition deposit(token: Token, amount: u64) -> (Token, Future) {
    let hash: field = BHP256::hash_to_field(token.owner);
    // ... return remaining token and finalize
    return (remaining, finalize_deposit(hash, amount));
}
```

**Privacy**: the mapping key is a hash of the address, making it harder (but not impossible) to link balances to addresses.

## Pattern 6: Multi-Program Privacy (Battleship Example)

Complex private applications split logic across multiple programs:
```leo
import board.aleo;
import move.aleo;
import verify.aleo;

program battleship.aleo {
    transition initialize_board(carrier: u64, battleship: u64, ...) -> board.aleo/BoardState {
        let valid: bool = verify.aleo/validate_ship(carrier, 5u64, 31u64, 4311810305u64);
        assert(valid);
        // ...
    }
}
```

Each program manages its own records, and they compose via cross-program calls.

## Design Guidelines

1. **Default to private**: use records unless you have a specific reason for public state
2. **Public aggregates only**: if you need public data, publish aggregates (totals, counts), not individual values
3. **Hash keys in mappings**: if mapping keys could reveal identity, hash them first
4. **Minimize public inputs**: mark transition inputs as `public` only when absolutely necessary
5. **Consider information leakage**: even with private records, transaction patterns (timing, frequency) can leak information
6. **Records are consumed**: you cannot "update" a record — you consume it and create new ones. Design accordingly.
