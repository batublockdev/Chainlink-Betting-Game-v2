// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// imports
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title HigherOrLower betting game
 * @author Batu block dev
 * @notice This is a contract for a simple betting game where the player bets on whether
 * the next card drawn from a deck will be higher, equal or lower than the previous card.
 * @dev This contract (Impelements Chainlink VRF)
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
    uint256 private s_total_Amount_Invested;
    uint256 private s_CEO_withdrawalAmount;
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private constant INVEST_AMOUNT = 1 ether;
    uint256 private constant MIN_BET = 0.5 ether;
    uint256 private s_lastTimeStamp;
    address payable private s_player;
    address payable[] private s_owners;
    uint256 private s_owners_length;
    Bet private s_bet;
    uint256 private s_betAmount;
    Bet_State private s_betState;
    uint256 private s_min_amount_owners = MIN_BET;
    uint256 private s_MaxBet;
    /**
     * @dev To start the game the contract denominated the number 3 as the first card
     */
    uint256 private s_previousCard = 3;

    modifier Game_State() {
        if (
            s_betState == Bet_State.CALCULATING ||
            s_betState == Bet_State.ONGAME
        ) {
            revert HigherOrLower_GAME_NOT_OPEN();
        }
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

    /**
     * @dev This funtion is used to set the maximum bet amount, taking into account
     * the minimum amount invested by the owners.
     */
    function setMaxBet() public {
        if (s_min_amount_owners < MIN_BET) {
            s_MaxBet = s_min_amount_owners * s_owners_length;
            s_betState = Bet_State.OPEN;
            emit State_Bet(uint256(s_betState));
        } else {
            s_MaxBet = MIN_BET * s_owners_length;
            s_betState = Bet_State.OPEN;
            emit State_Bet(uint256(s_betState));
        }
    }

    /**
     * @dev This function is used to invest in the game. The player must invest a minimum
     * amount of 5 ether to participate in the game, the maximun investors in the game is 5
     */
    function invest() public payable Game_State {
        if (msg.value < INVEST_AMOUNT) {
            revert HigherOrLower_IncorrectInvestmentAmount();
        }
        if (s_owners.length > 4) {
            revert HigherOrLower_OwnersMaximum_Completed();
        }
        bool exist = false;
        s_owners_length = s_owners.length;
        for (uint256 x = 0; x < s_owners_length; x++) {
            if (s_owners[x] == payable(msg.sender)) {
                exist = true;
                break;
            }
        }
        if (!exist) {
            s_owners.push(payable(msg.sender));
            s_owners_length = s_owners.length;
        }
        setMaxBet();
        owners_balances[msg.sender] += msg.value;
        s_total_Amount_Invested += msg.value;
    }

    /**
     * @dev This function is used to bet on the next card drawn from the deck.
     */
    function bet(uint256 bet_player) public payable {
        if (s_betState != Bet_State.OPEN) {
            revert HigherOrLower_GAME_NOT_OPEN();
        }

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
        // s_player size 10
        // randomNumber 202
        // 202 % 10 ? what's doesn't divide evenly into 202?
        // 20 * 10 = 200
        // 2
        // 202 % 10 = 2
        uint256 number_card = randomWords[0] % 10;
        /**
         * @dev The game is played with a deck of 10 cards, numbered from 0 to 9,
         * the player must bet if the next card will be higher, equal or lower than the previous card.
         * If the player wins the bet, the amount is doubled and returned to the player.
         */
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

    /**
     * @dev This function is used to transfer the winnings to the player.
     */
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

    /**
     * @dev This function is used to subtract the amount to the owners equally.
     * and set the maximun amount to bet in the next game iin the same way it cheks
     * if the owner balance is enough to play other round otherwise this owner is out the game.
     */
    function PayBet() internal {
        s_owners_length = s_owners.length;
        uint256 amount_to_pay = s_betAmount / s_owners_length;
        s_total_Amount_Invested -= s_betAmount;
        uint256 index = 0;
        s_min_amount_owners = MIN_BET;
        uint256 i = 0;
        while (i < s_owners_length) {
            if (i == index || i > index) {
                owners_balances[s_owners[i]] -= amount_to_pay;
            }
            if ((owners_balances[s_owners[i]] * s_owners_length) < MIN_BET) {
                if (s_owners_length == 1) {
                    s_owners.pop();
                    s_MaxBet = MIN_BET;
                    s_betState = Bet_State.CLOSED;
                    emit State_Bet(uint256(s_betState));
                    break;
                } else {
                    if (s_min_amount_owners == owners_balances[s_owners[i]]) {
                        s_min_amount_owners = MIN_BET;
                    }
                    for (uint256 x = i; x < s_owners_length - 1; x++) {
                        s_owners[x] = s_owners[x + 1];
                    }
                    s_owners.pop();
                    s_owners_length = s_owners.length;
                    s_MaxBet = MIN_BET * s_owners_length;
                    if (i != 0) {
                        index = i;
                        i = 0;
                    }
                }
            } else {
                if (s_min_amount_owners > owners_balances[s_owners[i]]) {
                    s_min_amount_owners = owners_balances[s_owners[i]];
                }
                setMaxBet();
                i++;
            }
        }
    }

    /**
     * @dev This function is used to withdraw the CEO funds from the contract who earns 10%
     * of each bet won by the contract.
     */
    function ceoWithdraw(uint256 amount_toWithdraw) public {
        if (msg.sender != s_CEO) {
            revert HigherOrLower_NotCEO();
        }
        if (s_CEO_withdrawalAmount < amount_toWithdraw) {
            revert HigherOrLower_NotEnoughFundsToWithdraw();
        }

        (bool callSuccess, ) = s_CEO.call{value: amount_toWithdraw}("");
        require(callSuccess, "Call failed");
        if (callSuccess) {
            s_CEO_withdrawalAmount -= amount_toWithdraw;
        }
    }

    /**
     * @dev This function is used to distribute the amount to the owners proportionally
     */

    function GetBetOwner() internal {
        /**
         * @dev If the player loses the bet, the amount is distributed to the owners
         * proportionally to the amount they have invested in the game before this round,
         * the CEO earns 10% of the amount lost by the player.
         */

        s_CEO_withdrawalAmount += (10 * s_betAmount) / 100;
        s_betAmount -= (10 * s_betAmount) / 100;
        s_owners_length = s_owners.length;

        for (uint256 i = 0; i < s_owners_length; i++) {
            uint256 s_percentage = (owners_balances[s_owners[i]] * 100) /
                (s_total_Amount_Invested);
            uint256 amount_to_pay_owner = (s_percentage * (s_betAmount)) / 100;

            if (owners_balances[s_owners[i]] == s_min_amount_owners) {
                s_min_amount_owners += amount_to_pay_owner;
            }
            owners_balances[s_owners[i]] += amount_to_pay_owner;
        }
        s_total_Amount_Invested += s_betAmount;
        setMaxBet();
    }

    /**
     * @dev This function is used to withdraw the amount by the owners
     * who must keep in the contract at least 1 ether to play a round .
     */
    function OwnerWithdraw(uint256 amount_toWithdraw) public Game_State {
        if (owners_balances[msg.sender] == 0) {
            revert HigherOrLower_BalanceIs0_Or_AddressIsnotValid();
        }
        if (owners_balances[msg.sender] < amount_toWithdraw) {
            revert HigherOrLower_NotEnoughFundsToWithdraw();
        }
        if (MIN_BET > (owners_balances[msg.sender] - amount_toWithdraw)) {
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

    function getOwners_legth() external view returns (uint256) {
        return s_owners.length;
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
        if (msg.sender != s_CEO) {
            revert HigherOrLower_NotCEO();
        }
        return s_CEO_withdrawalAmount;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
