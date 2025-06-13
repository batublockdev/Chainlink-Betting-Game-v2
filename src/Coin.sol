// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Coin
 * @dev A simple ERC20 token contract for a game.
 * This contract allows minting of tokens for testing purposes.
 * @author batublockdev
 * @notice The Coin contract is used in the HigherOrLower project to represent in-game currency.
 */
contract Coin is ERC20 {
    constructor() ERC20("CoinGame", "COIN") {}

    // Helper to mint more tokens in tests
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
