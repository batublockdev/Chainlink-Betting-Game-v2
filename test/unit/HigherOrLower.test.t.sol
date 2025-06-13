// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployHigherOrLower} from "../../script/DeployHigherOrLower.s.sol";
import {HigherOrLower} from "../../src/HigherOrLower.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {Coin} from "../../src/Coin.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "../../script/Interactions.s.sol";

contract HigherOrLowerTest is Test, CodeConstants {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    HigherOrLower public higherOrLower;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;
    Coin coin;

    address public XPLAYERX = makeAddr("XplayerX");
    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    address public PLAYER3 = makeAddr("player3");
    address public PLAYER4 = makeAddr("player4");
    address public PLAYER5 = makeAddr("player5");
    address public PLAYER6 = makeAddr("player6");

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant AMOUNT_BET = 5 ether;
    uint256 public constant AMOUNT_INVEST = 50 ether;

    uint256 public constant LINK_BALANCE = 4000 ether;

    function setUp() external {
        DeployHigherOrLower deployer = new DeployHigherOrLower();

        (higherOrLower, helperConfig, , ) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.deal(PLAYER2, STARTING_USER_BALANCE);
        vm.deal(PLAYER3, STARTING_USER_BALANCE);
        vm.deal(PLAYER4, STARTING_USER_BALANCE);
        vm.deal(PLAYER5, STARTING_USER_BALANCE);
        vm.deal(PLAYER6, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);
        coin = Coin(config.coin);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    function testGameInitializesInClosedState() public {
        assertEq(
            higherOrLower.getBet_State(),
            uint256(HigherOrLower.Bet_State.CLOSED)
        );
    }

    function testHigherOrLower_GAME_NOT_OPEN_INVEST() public {
        // Arrange
        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        vm.expectRevert(HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector);
        higherOrLower.invest();
    }

    function testHigherOrLower_IncorrectInvestmentAmount() public {
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_IncorrectInvestmentAmount.selector
        );
        higherOrLower.invest();
    }

    function testInvested() public {
        // Arrange
        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        higherOrLower.invest();
        vm.prank(PLAYER3);

        assertEq(higherOrLower.getOwnerBalance(), AMOUNT_INVEST);
    }

    function testSeveralTimesOwnerInvested() public {
        coin.mint(PLAYER3, AMOUNT_INVEST * 4);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST * 4);
        vm.prank(PLAYER3);
        higherOrLower.invest();
        vm.prank(PLAYER3);
        higherOrLower.invest();
        vm.prank(PLAYER3);
        higherOrLower.invest();
        vm.prank(PLAYER3);
        higherOrLower.invest();

        assertEq(higherOrLower.getOwners(0), PLAYER3);
        vm.prank(PLAYER3);
        assertEq(higherOrLower.getOwnerBalance(), (AMOUNT_INVEST * 4));
        assertEq(higherOrLower.getOwners_legth(), 1);
    }

    function testTooManyOwnersInvested() public {
        coin.mint(PLAYER, AMOUNT_INVEST);
        vm.prank(PLAYER);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER);
        higherOrLower.invest();

        ///
        coin.mint(PLAYER2, AMOUNT_INVEST);
        vm.prank(PLAYER2);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER2);
        higherOrLower.invest();

        ///
        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        higherOrLower.invest();

        ///
        coin.mint(PLAYER4, AMOUNT_INVEST);
        vm.prank(PLAYER4);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER4);
        higherOrLower.invest();

        ///
        coin.mint(PLAYER5, AMOUNT_INVEST);
        vm.prank(PLAYER5);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER5);
        higherOrLower.invest();

        ///
        coin.mint(PLAYER6, AMOUNT_INVEST);
        vm.prank(PLAYER6);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_OwnersMaximum_Completed.selector
        );
        vm.prank(PLAYER6);
        higherOrLower.invest();
    }

    function testErrors() public {
        // Arrange
        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        higherOrLower.invest();

        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        vm.prank(XPLAYERX);
        coin.mint(XPLAYERX, AMOUNT_BET);
        vm.prank(XPLAYERX);
        coin.approve(address(higherOrLower), AMOUNT_BET);
        vm.prank(XPLAYERX);
        higherOrLower.bet(0, AMOUNT_BET);

        vm.prank(PLAYER2);
        coin.mint(PLAYER2, AMOUNT_BET);
        vm.prank(PLAYER2);
        coin.approve(address(higherOrLower), AMOUNT_BET);
        vm.prank(PLAYER2);
        higherOrLower.bet(0, AMOUNT_BET);

        vm.prank(PLAYER3);
        coin.mint(PLAYER3, AMOUNT_BET);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_BET);
        vm.expectRevert(
            abi.encodeWithSelector(
                HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector
            )
        );
        vm.prank(PLAYER3);
        higherOrLower.bet(0, AMOUNT_BET);
    }

    function testGamex() public {
        // Arrange
        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        higherOrLower.invest();

        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        vm.prank(XPLAYERX);
        coin.mint(XPLAYERX, AMOUNT_BET);
        vm.prank(XPLAYERX);
        coin.approve(address(higherOrLower), AMOUNT_BET);
        vm.prank(XPLAYERX);
        higherOrLower.bet(0, AMOUNT_BET);

        vm.prank(PLAYER2);
        coin.mint(PLAYER2, AMOUNT_BET);
        vm.prank(PLAYER2);
        coin.approve(address(higherOrLower), AMOUNT_BET);
        vm.prank(PLAYER2);
        higherOrLower.bet(0, AMOUNT_BET);

        // Act
        vm.recordLogs();
        higherOrLower.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[2].topics[1]);
        bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
            uint256(
                0x0000000000000000000000000000000000000000000000000000000000000001
            ),
            address(higherOrLower)
        );

        // Assert

        console2.log("Bet #", coin.balanceOf(XPLAYERX));
        assertEq(coin.balanceOf(XPLAYERX), AMOUNT_BET * 2);
        assertEq(coin.balanceOf(PLAYER2), AMOUNT_BET * 2);
    }

    function testXOneOwnerBettingtheSame() public {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();

        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        higherOrLower.invest();

        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            coin.mint(XPLAYERX, AMOUNT_BET);
            vm.prank(XPLAYERX);
            coin.approve(address(higherOrLower), AMOUNT_BET);
            vm.prank(XPLAYERX);
            higherOrLower.bet(0, AMOUNT_BET);

            vm.prank(PLAYER2);
            coin.mint(PLAYER2, AMOUNT_BET);
            vm.prank(PLAYER2);
            coin.approve(address(higherOrLower), AMOUNT_BET);
            vm.prank(PLAYER2);
            higherOrLower.bet(0, AMOUNT_BET);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = 0;
            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert
            uint256 newCard = higherOrLower.getPreviousCard();
            bool betWin = false;

            if (previousCard > newCard) {
                if (bet == 0) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard == newCard) {
                if (bet == 1) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard < newCard) {
                if (bet == 2) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }

            if (betWin) {} else {}
            console2.log("Bet #", i);
            console2.log("Balance Game", higherOrLower.getBalance());

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            console2.log("Bet state: ", higherOrLower.getBet_State());
            if (higherOrLower.getBet_State() == 1) {
                break;
            }
        }
    }

    function testXOneOwnerDiferentBet() public {
        // Arrange
        address PLAYER_CEO = higherOrLower.getCEO();

        coin.mint(PLAYER3, AMOUNT_INVEST);
        vm.prank(PLAYER3);
        coin.approve(address(higherOrLower), AMOUNT_INVEST);
        vm.prank(PLAYER3);
        higherOrLower.invest();

        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + automationUpdateInterval + 1);
            vm.roll(block.number + 1);

            uint256 xbetAmountX = higherOrLower.getMaxtoBet();
            vm.prank(XPLAYERX);
            coin.mint(XPLAYERX, AMOUNT_BET);
            vm.prank(XPLAYERX);
            coin.approve(address(higherOrLower), AMOUNT_BET);
            vm.prank(XPLAYERX);
            higherOrLower.bet(0, AMOUNT_BET);

            vm.prank(PLAYER2);
            coin.mint(PLAYER2, AMOUNT_BET);
            vm.prank(PLAYER2);
            coin.approve(address(higherOrLower), AMOUNT_BET);
            vm.prank(PLAYER2);
            higherOrLower.bet(2, AMOUNT_BET);

            uint256 previousCard = higherOrLower.getPreviousCard();
            uint256 bet = 0;
            // Act
            vm.recordLogs();
            higherOrLower.performUpkeep(""); // emits requestId
            Vm.Log[] memory entries = vm.getRecordedLogs();
            console2.logBytes32(entries[2].topics[1]);
            bytes32 requestId = entries[2].topics[1]; // get the requestId from the logs

            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
                uint256(requestId),
                address(higherOrLower)
            );

            // Assert
            uint256 newCard = higherOrLower.getPreviousCard();
            bool betWin = false;

            if (previousCard > newCard) {
                if (bet == 0) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard == newCard) {
                if (bet == 1) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }
            if (previousCard < newCard) {
                if (bet == 2) {
                    betWin = true;
                } else {
                    betWin = false;
                }
            }

            if (betWin) {} else {}
            console2.log("Bet #", i);
            console2.log("Balance Game", higherOrLower.getBalance());

            console2.log("Balance player", XPLAYERX.balance);
            vm.prank(PLAYER2);
            console2.log("Balance owner 2", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER3);
            console2.log("Balance owner 3", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER4);
            console2.log("Balance owner 4 ", higherOrLower.getOwnerBalance());

            vm.prank(PLAYER5);
            console2.log("Balance owner 5 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER6);
            console2.log("Balance owner 6 ", higherOrLower.getOwnerBalance());
            vm.prank(PLAYER_CEO);

            console2.log(
                "Balance CEO ",
                higherOrLower.getCEOWithdrawalAmount()
            );

            console2.log("Max to Bet", higherOrLower.getMaxtoBet());
            console2.log("Bet state: ", higherOrLower.getBet_State());
            if (higherOrLower.getBet_State() == 1) {
                break;
            }
        }
    }
}
