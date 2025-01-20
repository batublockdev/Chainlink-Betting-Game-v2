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

/**
 * @title HigherOrLower betting game
 * @author Batu block dev
 * @notice This is a contract for a simple betting game where the player bets on whether the next card drawn from a deck will be higher or lower than the previous card.
 * @dev This contract is a work in progress and is not yet complete (Impelements Chainlink VRF)
 */

contract HigherOrLower is VRFConsumerBaseV2Plus {
    error HigherOrLower_IncorrectInvestmentAmount();
    error HigherOrLower_NotEnoughFundsToBet();
    error HigherOrLower_GAME_NOT_OPEN();
    error HigherOrLower_TooMuchFundsToBet();
    error HigherOrLower_IncorrectBet();
    error HigherOrLower_BalanceIs0_Or_AddressIsnotValid();
    error HigherOrLower_NotEnoughFundsToWithdraw();
    /* Type declarations */
    enum Bet {
        HIGH,
        EQUAL,
        LOW
    }
    enum Bet_State {
        OPEN,
        CLOSED,
        CALCULATING
    }

    /* State variables */
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    mapping(address => uint) owners_balances;

    // Lottery Variables
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    bool private s_BetState;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable private s_player;
    address payable[] private s_owners;
    Bet private s_bet;
    uint256 private s_betAmount;
    Bet_State private s_betState;
    uint256 private s_owners_length = s_owners.length;
    uint256 private s_min_amount_owners = 5 ether;
    uint256 private s_MaxBet = 1 ether * s_owners.length;
    //Initial card is 3
    uint256 private s_previousCard = 3;
    uint256 private constant INVEST_AMOUNT = 5 ether;
    uint256 private constant MIN_BET = 1 ether;

    modifier Game_State() {
        if (s_BetState != Bet_State.OPEN) revert HigherOrLower_GAME_NOT_OPEN();
        _;
    }

    constructor(
        address s_vrfCoordinator,
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint256 interval,
        uint256 entranceFee
    ) VRFConsumerBaseV2Plus(s_vrfCoordinator) {
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        s_betState = Bet_State.OPEN;
        s_bet = Bet.HIGH; // or any default state
    }

    function invest() public payable {
        if (s_BetState == Bet_State.CALCULATING) {
            revert HigherOrLower_GAME_NOT_OPEN();
        }
        if (msg.value < INVEST_AMOUNT) {
            revert HigherOrLower_IncorrectInvestmentAmount();
        }

        s_owners.push(msg.sender);
        owners_balances[msg.sender] += msg.value;
        s_betState = Bet_State.OPEN;
    }

    function bet(uint256 bet_player) public payable Game_State {
        if (msg.value < MIN_BET) {
            revert HigherOrLower_NotEnoughFundsToBet();
        }
        if (msg.value > s_MaxBet) {
            revert HigherOrLower_TooMuchFundsToBet();
        }
        if (0 > bet_player > 2) {
            revert HigherOrLower_IncorrectBet();
        }
        s_betState = Bet_State.CLOSED;
        s_bet = bet_player;
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
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
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
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_BetState = Bet_State.CALCULATING;

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
        // Quiz... is this redundant?
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
                WinnerWithdraw();
                PayBet();
            } else {
                GetBetOwner();
            }
        } else if (number_card == s_previousCard) {
            if (s_bet == Bet.EQUAL) {
                WinnerWithdraw();
                PayBet();
            } else {
                GetBetOwner();
            }
        } else {
            if (s_bet == Bet.LOW) {
                WinnerWithdraw();
                PayBet();
            } else {
                GetBetOwner();
            }
        }
        s_player = new address payable;

        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);
    }

    function WinnerWithdraw() internal {
        (bool callSuccess, ) = s_player.call{value: s_betAmount * 2}("");
        require(callSuccess, "Call failedxx");
    }

    function PayBet() internal {
        uint256 amount_to_pay = s_betAmount / s_owners_length;
        for (uint256 i = 0; i < s_owners_length; i++) {
            owners_balances[s_owners[i]] -= amount_to_pay;
            if (owners_balances[s_owners[i]] == 0) {
                if (s_owners_length == 1) {
                    s_owners.pop();
                    s_betState = Bet_State.CLOSED;
                } else {
                    // dellete data array
                    for (uint256 x = i; x < s_owners_length - 1; i++) {
                        s_owners[x] = s_owners[x + 1];
                    }
                    s_owners.pop();
                }
            } else if (s_min_amount_owners > owners_balances[s_owners[i]]) {
                s_min_amount_owners = owners_balances[s_owners[i]];
            }
        }
        if (s_min_amount_owners < 1) {
            s_MaxBet = s_min_amount_owners * s_owners.length;
            s_betState = Bet_State.OPEN;
        } else {
            s_MaxBet = 1 ether * s_owners.length;
            s_betState = Bet_State.OPEN;
        }
    }

    function GetBetOwner() internal {
        uint256 total_Amount_Invested = this.balance - s_betAmount;
        for (uint256 i = 0; i < s_owners_length; i++) {
            uint256 s_percentage = (owners_balances[s_owners[i]] * 100) /
                (total_Amount_Invested);
            uint256 amount_to_pay_owner = (s_percentage * s_betAmount) / 100;
            owners_balances[s_owners[i]] += amount_to_pay_owner;
            if (owners_balances[s_owners[i]] == s_min_amount_owners) {
                s_min_amount_owners += amount_to_pay_owner;
            }
        }
        s_betState = Bet_State.OPEN;
    }

    function OwnerWithdraw(uint256 amount_toWithdraw) public Game_State {
        if (owners_balances[msg.sender] == 0) {
            revert HigherOrLower_BalanceIs0_Or_AddressIsnotValid();
        }
        if ((owners_balances[msg.sender] - INVEST_AMOUNT) < amount_toWithdraw) {
            revert HigherOrLower_NotEnoughFundsToWithdraw();
        }
        (bool callSuccess, ) = msg.sender.call{value: amount_toWithdraw}("");
        require(callSuccess, "Call failed");
        owners_balances[msg.sender] = 0;
    }

    function OwnerBalance() public Game_State {
        if (owners_balances[msg.sender] == 0) {
            revert HigherOrLower_BalanceIs0_Or_AddressIsnotValid();
        }
        uint256 amount = owners_balances[msg.sender] - INVEST_AMOUNT;
        return amount;
    }
}
