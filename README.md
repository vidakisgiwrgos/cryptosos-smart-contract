# CryptoSOS — On-Chain SOS Game in Solidity

An Ethereum smart contract implementation of the classic SOS game with built-in Ether incentives, timeout logic and security protections.

Developed as part of the MSc in Computer Science.

---

## Core Features

- Fully on-chain game logic
- 3-state finite state machine (Idle / Waiting / Active)
- Bit-packed board representation (2 bits per cell)
- Turn enforcement and square validation
- Event-driven architecture

---

## Incentive Design

- 1 ETH deposit per player
- 1.8 ETH reward for winner
- 0.95 ETH refund each in case of tie
- Timeout win logic
- Owner withdrawal via sweepBalance()

---

## Security Measures

- Reentrancy guard
- Checks-Effects-Interactions pattern
- Strict phase validation
- Self-play prevention
- Timestamp tolerance analysis
- Gas-aware storage packing

---

## Technical Design Highlights

- Board stored in uint32 (gas optimization)
- Helper functions for cell access
- State reset before transfers
- Time-based logic enforced via callable functions

---

## Repository Structure

- `contracts/` – Smart contract implementation
- `docs/` – Design decisions and security analysis

---

## Status

Academic project – completed.
