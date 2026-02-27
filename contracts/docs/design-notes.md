[readme.md](https://github.com/user-attachments/files/25604063/readme.md)
# CryptoSOS – Blockchain Assignment

## 1. Overview

CryptoSOS is a Solidity smart contract that implements the SOS game for two players.  
Each player deposits **1 ether** to play and the entire game logic runs on the blockchain.

The contract has three states:

- **Idle**: no game exists  
- **Waiting**: the first player has joined and is waiting for an opponent  
- **Active**: the game is currently being played  

---

## 2. Design and Implementation Notes

The contract is implemented as a simple **state machine** (Idle / Waiting / Active) to control which actions are allowed at each stage.

The 3x3 board is stored using **bit packing** in a `uint32` (2 bits per cell) to keep storage usage small.  
Players interact with squares numbered **1–9**, but internally the contract uses indices **0–8** (`square - 1`), which simplifies board checks and indexing.

Timeouts (`cancel` and `tooslow`) are based on `block.timestamp`.  
Since smart contracts do not run automatically, time-based rules are enforced only when the corresponding function is called.

Ether transfers are done only after the contract state is reset and a **reentrancy guard** is used to protect against reentrant calls.

---

## 3. Difficulties and Design Decisions

- **Handling time**: Time does not pass “inside” the contract, so all timeouts must be enforced through function calls (`cancel()` and `tooslow()`).
- **Correct payouts**: Different outcomes (win, tie, cancel, tooslow) require different ETH transfers, so the order of state reset and payment is important.
- **Storage vs readability**: Packed storage reduces gas usage but requires helper functions (`_cell` / `_setCell`) to keep the code readable.

---

## 4. Game Flow

1. The first player calls `join()` and deposits **1 ether**.  
2. The contract enters the **Waiting** state.  
3. The second player calls `join()` and deposits **1 ether**.  
4. The game starts (**Active** state).  
5. Players take turns placing either **S** or **O** on squares 1–9.  
6. If an **SOS pattern** is formed, the player who made the move wins.  
7. If the board is filled without any SOS, the game ends in a tie.

---

## 5. Moves (`placeS` / `placeO`)

Players place letters using `placeS` or `placeO`.

The contract checks that:

- Only the correct player can move  
- The chosen square is empty  
- Moves can only be made during the **Active** phase  

---

## 6. Ether Handling

- Each player deposits exactly **1 ether** (`msg.value == 1 ether`).
- The winner receives **1.8 ether**.
- In case of a tie, each player receives **0.95 ether**.
- In a `tooslow` win, the winner receives **1.5 ether**.

Any remaining ether stays in the contract.

> **Note:** Players also pay gas fees, which do not go to the contract.

---

## 7. Cancel and Timeouts

If the second player does not join within **2 minutes**, the first player can call `cancel()` and receive their **1 ether** back.

If no move is made for **1 minute**, the player who made the last move can call `tooslow()` and win the game.

If no move is made for **5 minutes**, the owner can call `tooslow()` and the game ends in a tie.

The helper function `secondsSinceLastAction()` shows how many seconds have passed since the last move.

---

## 8. `sweepBalance`

The `sweepBalance` function allows the owner to withdraw ether from the contract, but only if enough balance remains to pay players in case of a cancel or tie.

The amount is given in **wei** (not ether).

1 ether = 1,000,000,000,000,000,000 wei (10^18 wei)


### Example

If the contract has **0.5 ether** available to withdraw, the owner must call:

sweepBalance(500000000000000000)


---

## 9. Owner Participation

The owner can also participate as `player1` or `player2`.

If the owner should not be allowed to play, a simple check could be added in `join()`, for example requiring:

msg.sender != owner


while still allowing owner-only functions.

---

## 10. Security Considerations

- **Reentrancy / DAO-style attacks**: Prevented using a reentrancy guard and by resetting the state before sending ether (checks-effects-interactions).
- **Invalid moves / cheating**: Prevented by enforcing turn order, empty squares and correct phase checks.
- **Self-play**: The same address cannot join as both `player1` and `player2`.
- **Timestamp manipulation**: `block.timestamp` is used for timeouts. Miners can slightly influence timestamps, but not enough to realistically break 1–5 minute rules.
- **51% attack**: This is a network-level issue related to consensus and cannot be prevented at the contract level.

### Main Known Limitation

- **Payout DoS**: ETH is sent directly to players using `call()`. If a player is a contract that rejects ETH, payouts (win, tie or cancel) could fail.  
  A safer alternative would be a **withdraw pattern**, but direct payouts are used in this assignment.

---

## 11. Storage and `uint256` Usage

Most `uint256` variables are used only for temporary calculations (balances, elapsed time) and are not stored permanently.

Stored state variables are kept small where possible:

- `uint32` for the board  
- `uint8` for counters  
- `uint64` for timestamps  

Using `uint256` for local variables does **not** increase the contract’s storage cost.
