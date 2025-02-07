// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// imports
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title HigherOrLower betting game
 * @author Batu block dev
 * @notice This is a contract for a simple betting game where the player bets on whether the next card drawn from a deck will be higher or lower than the previous card.
 * @dev This contract is a work in progress and is not yet complete (Impelements Chainlink VRF)
 */

contract HigherOrLower is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    // errors
    error HigherOrLower_IncorrectInvestmentAmount();
    error HigherOrLower_NotEnoughFundsToBet();
    error HigherOrLower_GAME_NOT_OPEN();
    error HigherOrLower_TooMuchFundsToBet();
    error HigherOrLower_IncorrectBet();
    error HigherOrLower_BalanceIs0_Or_AddressIsnotValid();
    error HigherOrLower_NotEnoughFundsToWithdraw();
    error HigherOrLower_NotCEO();
    error HigherOrLower_OwnersMaximum_Completed();
    error HigherOrLower_UpkeepNotNeeded(
        uint256 currentBalance,
        address player,
        uint256 bet_State
    );

    /* Type declarations */
    enum Bet {
        LOW,
        EQUAL,
        HIGH
    }
    enum Bet_State {
        OPEN,
        CLOSED,
        CALCULATING,
        ONGAME
    }

    /* State variables */
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    mapping(address => uint) owners_balances;

    // Game Variables
    address payable public s_CEO;
    uint256 private s_CEO_withdrawalAmount;
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private constant INVEST_AMOUNT = 5 ether;
    uint256 private constant MIN_BET = 1 ether;
    uint256 private s_lastTimeStamp;
    address payable private s_player;
    address payable[] private s_owners;
    uint256 private s_owners_length;
    Bet private s_bet;
    uint256 private s_betAmount;
    Bet_State private s_betState;
    uint256 private s_min_amount_owners = 1 ether;
    uint256 private s_MaxBet;
    /**
     * @dev To start the game the contract denominated the number 3 as the first card
     */
    uint256 private s_previousCard = 3;

    modifier Game_State() {
        if (s_betState != Bet_State.OPEN) revert HigherOrLower_GAME_NOT_OPEN();
        _;
    }

    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event State_Bet(uint256 indexed betState);
    event CurrentCard(uint256 indexed card);

    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        s_betState = Bet_State.CLOSED;
        s_bet = Bet.HIGH; // or any default state
        s_min_amount_owners = INVEST_AMOUNT;
        s_CEO = payable(msg.sender);
    }

    function setMaxBet() public {
        if (s_min_amount_owners < 1 ether) {
            s_MaxBet = s_min_amount_owners * s_owners_length;
            s_betState = Bet_State.OPEN;
            emit State_Bet(uint256(s_betState));
        } else {
            s_MaxBet = MIN_BET * s_owners_length;
            s_betState = Bet_State.OPEN;
            emit State_Bet(uint256(s_betState));
        }
    }

    function invest() public payable {
        if (
            s_betState == Bet_State.CALCULATING ||
            s_betState == Bet_State.ONGAME
        ) {
            revert HigherOrLower_GAME_NOT_OPEN();
        }
        if (msg.value < INVEST_AMOUNT) {
            revert HigherOrLower_IncorrectInvestmentAmount();
        }
        if (s_owners.length > 4) {
            revert HigherOrLower_OwnersMaximum_Completed();
        }
        bool exist = false;
        for (uint256 x = 0; x < s_owners_length; x++) {
            if (s_owners[x] == payable(msg.sender)) {
                exist = true;
                break;
            }
        }
        if (!exist) {
            s_owners.push(payable(msg.sender));
        }
        s_owners_length = s_owners.length;
        setMaxBet();
        owners_balances[msg.sender] += msg.value;
    }

    function bet(uint256 bet_player) public payable Game_State {
        if (msg.value < MIN_BET) {
            revert HigherOrLower_NotEnoughFundsToBet();
        }
        if (msg.value > s_MaxBet) {
            revert HigherOrLower_TooMuchFundsToBet();
        }
        if (bet_player < 0 || bet_player > 2) {
            revert HigherOrLower_IncorrectBet();
        }
        s_betState = Bet_State.ONGAME;
        emit State_Bet(uint256(s_betState));
        s_bet = Bet(bet_player);
        s_player = payable(msg.sender);
        s_betAmount = msg.value;
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = Bet_State.ONGAME == s_betState ||
            Bet_State.CALCULATING == s_betState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_player != address(0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert HigherOrLower_UpkeepNotNeeded(
                address(this).balance,
                s_player,
                uint256(s_betState)
            );
        }

        s_betState = Bet_State.CALCULATING;
        emit State_Bet(uint256(s_betState));

        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(
        uint256,
        /* requestId */ uint256[] calldata randomWords
    ) internal override {
        // s_players size 10
        // randomNumber 202
        // 202 % 10 ? what's doesn't divide evenly into 202?
        // 20 * 10 = 200
        // 2
        // 202 % 10 = 2
        uint256 number_card = randomWords[0] % 10;
        if (number_card > s_previousCard) {
            if (s_bet == Bet.HIGH) {
                PayBet();
                WinnerWithdraw();
            } else {
                GetBetOwner();
            }
        } else if (number_card == s_previousCard) {
            if (s_bet == Bet.EQUAL) {
                PayBet();
                WinnerWithdraw();
            } else {
                GetBetOwner();
            }
        } else {
            if (s_bet == Bet.LOW) {
                PayBet();
                WinnerWithdraw();
            } else {
                GetBetOwner();
            }
        }
        s_previousCard = number_card;
        emit CurrentCard(number_card);
        s_player = payable(address(0));
        s_lastTimeStamp = block.timestamp;
    }

    function WinnerWithdraw() internal {
        require(s_betAmount <= type(uint256).max / 2, "Bet amount too large");

        uint256 withdrawalAmount = s_betAmount * 2;

        // Ensure the contract has enough balance
        require(
            address(this).balance >= withdrawalAmount,
            "Insufficient contract balance"
        );

        // Ensure the multiplication doesn't overflow uint256
        require(withdrawalAmount >= s_betAmount, "Overflow detected");
        // Attempt to transfer the winnings
        (bool callSuccess, ) = s_player.call{value: withdrawalAmount}("");
        require(
            callSuccess,
            "Withdrawal failed: call to player was unsuccessful"
        );
    }

    function PayBet() internal {
        s_owners_length = s_owners.length;
        bool s_zero = false;
        uint256 amount_to_pay = s_betAmount / s_owners_length;
        s_min_amount_owners = 1 ether;
        for (uint256 i = 0; i < s_owners_length; i++) {
            if (s_zero == true) {
                i = 0;
                s_zero = false;
            }
            owners_balances[s_owners[i]] -= amount_to_pay;
            if ((owners_balances[s_owners[i]] * s_owners_length) < 1 ether) {
                if (s_owners_length == 1) {
                    s_owners.pop();
                    s_MaxBet = MIN_BET;
                    s_betState = Bet_State.CLOSED;
                    emit State_Bet(uint256(s_betState));
                    break;
                } else {
                    for (uint256 x = i; x < s_owners_length - 1; x++) {
                        s_owners[x] = s_owners[x + 1];
                    }
                    s_owners.pop();
                    s_owners_length = s_owners.length;
                    s_MaxBet = MIN_BET * s_owners_length;
                    if (i == 0) {
                        s_zero = true;
                    } else {
                        i--;
                    }
                    if (s_owners_length == 1) {
                        owners_balances[s_owners[i]] -= amount_to_pay;
                        if (owners_balances[s_owners[0]] < 1 ether) {
                            s_owners.pop();
                            s_MaxBet = MIN_BET;
                            s_min_amount_owners = 1 ether;
                            s_betState = Bet_State.CLOSED;
                            emit State_Bet(uint256(s_betState));
                        } else {
                            s_MaxBet = MIN_BET;
                            s_min_amount_owners = 1 ether;
                            s_betState = Bet_State.OPEN;
                            emit State_Bet(uint256(s_betState));
                        }
                    }
                }
            } else {
                if (s_min_amount_owners > owners_balances[s_owners[i]]) {
                    s_min_amount_owners = owners_balances[s_owners[i]];
                }
                setMaxBet();
            }
        }
    }

    function CEOWithdraw(uint256 amount_toWithdraw) internal {
        if (msg.sender != s_CEO) {
            revert HigherOrLower_NotCEO();
        }
        if (s_CEO_withdrawalAmount < amount_toWithdraw) {
            revert HigherOrLower_NotEnoughFundsToWithdraw();
        }

        (bool callSuccess, ) = s_CEO.call{value: amount_toWithdraw}("");
        require(callSuccess, "Call failed");
        if (callSuccess) {
            owners_balances[msg.sender] -= amount_toWithdraw;
        }
    }

    function GetBetOwner() internal {
        /**
         * @dev If the player loses the bet, the amount is distributed to the owners
         * proportionally to the amount they invested in the game before this round.
         */
        uint256 total_Amount_Invested = address(this).balance - s_betAmount;

        s_CEO_withdrawalAmount += (10 * s_betAmount) / 100;
        s_betAmount -= (10 * s_betAmount) / 100;
        s_owners_length = s_owners.length;

        for (uint256 i = 0; i < s_owners_length; i++) {
            uint256 s_percentage = (owners_balances[s_owners[i]] * 100) /
                (total_Amount_Invested);
            uint256 amount_to_pay_owner = (s_percentage * (s_betAmount)) / 100;

            if (owners_balances[s_owners[i]] == s_min_amount_owners) {
                s_min_amount_owners += amount_to_pay_owner;
            }
            owners_balances[s_owners[i]] += amount_to_pay_owner;
        }
        setMaxBet();
    }

    function OwnerWithdraw(uint256 amount_toWithdraw) public Game_State {
        if (owners_balances[msg.sender] == 0) {
            revert HigherOrLower_BalanceIs0_Or_AddressIsnotValid();
        }
        if (owners_balances[msg.sender] < amount_toWithdraw) {
            revert HigherOrLower_NotEnoughFundsToWithdraw();
        }
        if (1 ether > (owners_balances[msg.sender] - amount_toWithdraw)) {
            revert HigherOrLower_NotEnoughFundsToWithdraw();
        }
        (bool callSuccess, ) = msg.sender.call{value: amount_toWithdraw}("");
        require(callSuccess, "Call failed");
        if (callSuccess) {
            owners_balances[msg.sender] -= amount_toWithdraw;
        }
    }

    function getOwnerBalance() public view returns (uint256) {
        uint256 amount;
        if (owners_balances[msg.sender] == 0) {
            amount = 0;
        }

        amount = owners_balances[msg.sender];

        return amount;
    }

    function getPreviousCard() public view returns (uint256) {
        return s_previousCard;
    }

    function getOwners(
        uint256 indexOwners
    ) external view returns (address payable) {
        return s_owners[indexOwners];
    }

    function getBet_State() public view returns (uint256) {
        return uint256(s_betState);
    }

    function getBet() public view returns (uint256) {
        return uint256(s_bet);
    }

    function getMaxtoBet() public view returns (uint256) {
        return uint256(s_MaxBet);
    }

    function getPlayer() public view returns (address) {
        return s_player;
    }

    function getBetAmount() public view returns (uint256) {
        return s_betAmount;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getCEO() public view returns (address payable) {
        return s_CEO;
    }

    function getCEOWithdrawalAmount() public view returns (uint256) {
        return s_CEO_withdrawalAmount;
    }
}
