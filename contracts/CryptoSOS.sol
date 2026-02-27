// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CryptoSOS {
    // -------------------- Events --------------------
    event StartGame(address indexed p1, address indexed p2);
    event Move(address indexed player, uint8 square, uint8 letter); // 1=S, 2=O
    event Winner(address indexed winner);
    event Tie(address indexed p1, address indexed p2);

    // -------------------- Money rules --------------------
    uint256 private constant JOIN_FEE = 1 ether;
    uint256 private constant WIN_PRIZE = 1.8 ether;
    uint256 private constant TIE_REFUND_EACH = 0.95 ether;
    uint256 private constant TOOSLOW_WIN_REFUND = 1.5 ether;

    // -------------------- Time rules --------------------
    uint256 private constant WAIT_TIMEOUT = 2 minutes;  // player1 can cancel after this
    uint256 private constant MOVE_TIMEOUT = 1 minutes;  // last mover can claim win after this
    uint256 private constant IDLE_TIMEOUT = 5 minutes;  // owner can force tie after this

    // -------------------- Owner + reentrancy guard --------------------
    address public immutable owner;
    uint256 private locked; // 0 = unlocked, 1 = locked

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier nonReentrant() {
        require(locked == 0, "Reentrancy");
        locked = 1;
        _;
        locked = 0;
    }

    // -------------------- Game phase --------------------
    // We keep this because the contract must behave differently depending on:
    // - nobody playing yet
    // - waiting for second player
    // - active game in progress
    enum Phase { Idle, Waiting, Active }
    Phase public phase;

    // -------------------- Players --------------------
    address public player1;
    address public player2;

    // -------------------- Board storage --------------------
    // 2 bits per cell (0 empty, 1=S, 2=O), 9 cells => 18 bits total
    uint32 private board;
    uint8 public movesPlayed;

    // 0 => player1 turn, 1 => player2 turn
    uint8 private turn;

    // -------------------- Timers (kept private to reduce UI clutter) --------------------
    // When player1 joined and we started waiting for player2
    uint64 private waitingSince;

    // When the last action happened (game start counts as an action)
    uint64 private lastActionTime;

    // Who made the most recent move (used for tooslow rule)
    address public lastMover;

    constructor() {
        owner = msg.sender;
        phase = Phase.Idle;
    }

    // -------------------- Joining / canceling --------------------

    function join() external payable nonReentrant {
        // User must send exactly 1 ETH to the contract (gas is separate and unavoidable)
        require(msg.value == JOIN_FEE, "Send exactly 1 ether");

        if (phase == Phase.Idle) {
            // First player enters lobby
            player1 = msg.sender;
            player2 = address(0);
            phase = Phase.Waiting;

            waitingSince = uint64(block.timestamp);

            // Optional: shows lobby created (player2 is 0 address)
            emit StartGame(player1, address(0));
            return;
        }

        if (phase == Phase.Waiting) {
            // Second player enters and the game begins
            require(msg.sender != player1, "No self-play");

            player2 = msg.sender;
            phase = Phase.Active;

            // Reset game state for a new match
            board = 0;
            movesPlayed = 0;
            turn = 0; // player1 starts

            lastActionTime = uint64(block.timestamp);
            lastMover = address(0);

            emit StartGame(player1, player2);
            return;
        }

        revert("Game already active");
    }

    function cancel() external nonReentrant {
        // Only valid while waiting for player2
        require(phase == Phase.Waiting, "Not waiting");
        require(msg.sender == player1, "Only player1");
        require(block.timestamp >= uint256(waitingSince) + WAIT_TIMEOUT, "Too early");

        address p1 = player1;

        // Reset first, then refund
        _reset();

        _safeSend(p1, JOIN_FEE);
    }

    // -------------------- Moves --------------------

    function placeS(uint8 square) external nonReentrant {
        _place(square, 1);
    }

    function placeO(uint8 square) external nonReentrant {
        _place(square, 2);
    }

    function _place(uint8 square, uint8 letter) internal {
        require(phase == Phase.Active, "No active game");
        require(square >= 1 && square <= 9, "Square must be 1..9");
        require(letter == 1 || letter == 2, "Bad letter");

        address current = (turn == 0) ? player1 : player2;
        require(msg.sender == current, "Not your turn");

        uint8 idx = square - 1;
        require(_cell(idx) == 0, "Square occupied");

        // Store move
        _setCell(idx, letter);

        unchecked { movesPlayed += 1; }

        emit Move(msg.sender, square, letter);

        // Update timing info used by tooslow
        lastActionTime = uint64(block.timestamp);
        lastMover = msg.sender;

        // Check win
        if (_hasSOS()) {
            address winner = msg.sender;

            _reset();
            emit Winner(winner);
            _safeSend(winner, WIN_PRIZE);
            return;
        }

        // Check tie (board full)
        if (movesPlayed == 9) {
            address p1 = player1;
            address p2 = player2;

            _reset();
            emit Tie(p1, p2);
            _safeSend(p1, TIE_REFUND_EACH);
            _safeSend(p2, TIE_REFUND_EACH);
            return;
        }

        // Switch turn
        turn ^= 1;
    }

    // -------------------- Slow-play rules --------------------

    function tooslow() external nonReentrant {
        require(phase == Phase.Active, "No active game");

        uint256 elapsed = block.timestamp - uint256(lastActionTime);

        // If someone is taking too long (>= 1 minute), last mover can claim win
        if (elapsed >= MOVE_TIMEOUT && elapsed < IDLE_TIMEOUT) {
            require(lastMover != address(0), "No moves yet");
            require(msg.sender == lastMover, "Only last mover");

            address winner = lastMover;

            _reset();
            emit Winner(winner);
            _safeSend(winner, TOOSLOW_WIN_REFUND);
            return;
        }

        // If nobody has acted for >= 5 minutes, the owner can force a tie
        if (elapsed >= IDLE_TIMEOUT) {
            require(msg.sender == owner, "Only owner");

            address p1 = player1;
            address p2 = player2;

            _reset();
            emit Tie(p1, p2);
            _safeSend(p1, TIE_REFUND_EACH);
            _safeSend(p2, TIE_REFUND_EACH);
            return;
        }

        revert("Not eligible");
    }

    // Τimer for players.
    // It returns how many seconds since the last move (or game start).
    function secondsSinceLastAction() external view returns (uint64) {
        if (phase != Phase.Active) return 0;
        return uint64(block.timestamp - uint256(lastActionTime));
    }

    // -------------------- Board view --------------------

    function getGameState() external view returns (string memory) {
        bytes memory out = new bytes(9);
        for (uint8 i = 0; i < 9; i++) {
            uint8 v = _cell(i);
            out[i] = (v == 0) ? bytes1("-") : (v == 1 ? bytes1("S") : bytes1("O"));
        }
        return string(out);
    }

    // -------------------- Owner withdrawal with reserve --------------------

    function sweepBalance(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount=0");

        uint256 bal = address(this).balance;
        require(bal >= amount, "Insufficient");

        // Keep enough ETH to pay obligations depending on current phase
        uint256 reserve = _requiredReserve();
        require(bal - amount >= reserve, "Keep reserve");

        _safeSend(owner, amount);
    }

    function _requiredReserve() internal view returns (uint256) {
        // If waiting: must be able to refund player1 (1 ETH)
        if (phase == Phase.Waiting) return JOIN_FEE;

        // If active: worst case is tie refund (0.95 + 0.95 = 1.9 ETH)
        if (phase == Phase.Active) return 1.9 ether;

        // Idle: no obligations
        return 0;
    }

    // -------------------- SOS logic --------------------

    function _hasSOS() internal view returns (bool) {
        // rows
        if (_isSOS(0, 1, 2)) return true;
        if (_isSOS(3, 4, 5)) return true;
        if (_isSOS(6, 7, 8)) return true;

        // columns
        if (_isSOS(0, 3, 6)) return true;
        if (_isSOS(1, 4, 7)) return true;
        if (_isSOS(2, 5, 8)) return true;

        // diagonals
        if (_isSOS(0, 4, 8)) return true;
        if (_isSOS(2, 4, 6)) return true;

        return false;
    }

    function _isSOS(uint8 a, uint8 b, uint8 c) internal view returns (bool) {
        return _cell(a) == 1 && _cell(b) == 2 && _cell(c) == 1;
    }

    // -------------------- Packed board helpers --------------------

    function _cell(uint8 idx) internal view returns (uint8) {
        return uint8((board >> (idx * 2)) & 0x3);
    }

    function _setCell(uint8 idx, uint8 val) internal {
        uint32 shift = uint32(idx) * 2;
        uint32 mask = uint32(3) << shift;
        board = (board & ~mask) | (uint32(val) << shift);
    }

    // -------------------- Reset + payment --------------------

    function _reset() internal {
        phase = Phase.Idle;
        player1 = address(0);
        player2 = address(0);

        board = 0;
        movesPlayed = 0;
        turn = 0;

        waitingSince = 0;
        lastActionTime = 0;
        lastMover = address(0);
    }

    function _safeSend(address to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Transfer failed");
    }
}
