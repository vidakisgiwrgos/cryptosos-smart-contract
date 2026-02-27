# CryptoSOS — On-Chain SOS Game (Solidity)

A fully on-chain implementation of the classic SOS game built in Solidity for the Ethereum blockchain.

Developed as part of the MSc in Computer Science (AUEB).

---

## 🎮 Game Overview

CryptoSOS is a two-player on-chain game where:

- Players join by paying **1 ether**
- A 3x3 board is created
- Players alternately place **S** or **O**
- The first to form "SOS" (horizontally, vertically, or diagonally) wins
- If the board fills without "SOS", the game ends in a tie

---

## 💰 Incentive Mechanism

- Winner receives **1.8 ether**
- Smart contract retains **0.2 ether**
- In case of tie, each player receives **0.95 ether**
- Owner can withdraw accumulated fees via `sweepBalance()`

---

## ⏱ Timeout Logic

- If second player does not join within 2 minutes → first player can `cancel()`
- If a player delays move for 1 minute → opponent can call `tooslow()`
- If no activity for 5 minutes → owner may terminate game (tie)

---

## 📡 Events

- `StartGame(address, address)`
- `Move(address, uint8, uint8)`
- `Winner(address)`
- `Tie(address, address)`

---

## 🛡 Security Considerations

The contract design considers:

- Reentrancy risks in Ether transfers
- Proper use of `require()` validations
- State updates before transfers
- Controlled owner-only functions
- Gas optimization in storage usage
- Prevention of self-play

---

## 🧠 Design Notes

The contract was designed to:
- Minimize storage operations
- Keep board representation compact
- Emit clear event logs for off-chain monitoring
- Enforce strict game state transitions

---

## 🛠 Tech Stack

- Solidity
- Ethereum Virtual Machine (EVM)

---

## 📂 Project Structure

- `contracts/` — Solidity smart contract implementation
- `docs/` — Design notes and additional documentation
- `assets/` — Diagrams or visual explanations

---

## 📌 Status

Academic project — completed.
