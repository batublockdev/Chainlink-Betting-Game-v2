
# 🎰 Higher or Lower – Decentralized Betting Game

A fully on-chain betting game where users wager on whether the next card drawn will be **higher**, **equal**, or **lower** than the previous one. Built with Solidity, powered by **Chainlink VRF v2+**, and tokenized using a custom `Coin` ERC-20 contract.

---

## 🛠️ Features

- 🧠 Smart contract logic for managing bets, results, and payouts
- 🔒 Fair randomness through Chainlink VRF v2+ (Plus mode)
- 👥 Investor (owner) model for liquidity with profit sharing
- ⚙️ Automated game resolution using Chainlink Automation
- 💸 ERC-20-based betting with withdrawal functionality

---

## 📦 Smart Contracts

### `HigherOrLower.sol`

| Function | Purpose |
|---------|---------|
| `invest()` | Invest in the game and become an owner |
| `bet(betType, amount)` | Place a bet (LOW, EQUAL, HIGH) |
| `performUpkeep()` | Triggered by Chainlink Automation to settle bets |
| `fulfillRandomWords()` | Called by Chainlink VRF to resolve the game |
| `ceoWithdraw()` | Allows the CEO to withdraw profit (10% fee) |
| `OwnerWithdraw()` | Allows owners to withdraw their capital |

Additional getters are included to query state variables, like current card, owners, balances, and betting state.

---

## 🎲 Game Mechanics

- Deck consists of cards numbered `0–9`.
- Player bets whether the next card is **LOW** (0), **EQUAL** (1), or **HIGH** (2) compared to the previous.
- If the bet is correct, the player receives **2x** the wager.
- If incorrect, the loss is distributed to owners and 10% to the CEO.
- A maximum of **5 owners** can fund the game pool.

---

## 🔗 Integrations

- ✅ **Chainlink VRF v2+** for secure and verifiable randomness
- ✅ **Chainlink Automation** for timed game execution
- ✅ **ERC-20 Coin contract** for betting and investment
- ✅ **Foundry** for development and testing

---

## ⚙️ How to Use

### Prerequisites

- Deploy your custom `Coin` ERC-20 contract
- Fund Chainlink VRF subscription
- Deploy `HigherOrLower` with:
  - `subscriptionId`
  - `gasLane` (keyHash)
  - `interval`
  - `entranceFee`
  - `callbackGasLimit`
  - `vrfCoordinatorV2`
  - `Coin address`

### Game Flow

1. Owners invest `50 Coin` tokens to fund the game.
2. Players place bets of `>= 5 Coin`.
3. Once enough bets are placed or time passes, Chainlink resolves the round.
4. Winnings are distributed and game resets for the next round.

---

## 🧪 Development

Built with [Foundry](https://book.getfoundry.sh/):

```bash
forge install
forge build
forge test
```

---

## 📄 License

MIT

---

## 👨‍💻 Author

Developed by **Batu block dev**

---

## 🌐 Deployment

This smart contract is deployed on the **Sepolia Testnet**:

- **Contract Name:** `HigherOrLower`
- **Network:** Sepolia
- **Contract Address:** [`0x0DfD5C56F7e4fA2f8aE480edAecbBfD5096B212d`](https://sepolia.etherscan.io/address/0x0DfD5C56F7e4fA2f8aE480edAecbBfD5096B212d)
- **Token Used:** Custom ERC-20 Coin (`Coin.sol`)  
  [`0x380F58cB97395D36dCb69bc1c9A4865789e99C14`](https://sepolia.etherscan.io/address/0x380F58cB97395D36dCb69bc1c9A4865789e99C14)
