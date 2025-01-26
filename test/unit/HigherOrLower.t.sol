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

    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployHigherOrLower deployer = new DeployHigherOrLower();
        (higherOrLower, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.deal(PLAYER2, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);

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

    function testGameInitializesInOpenState() public {
        assertEq(
            higherOrLower.getBet_State(),
            uint256(HigherOrLower.Bet_State.OPEN)
        );
    }

    function testHigherOrLower_IncorrectInvestmentAmount() public {
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_IncorrectInvestmentAmount.selector
        );
        higherOrLower.invest();
    }

    function testOwnerInvested() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        assertEq(higherOrLower.getOwnerBalance(), 3 ether);
    }

    function testOwneradd() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        assertEq(higherOrLower.getOwners(0), PLAYER);
    }

    function testInvenstBetStateChanged() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 8 ether}();
        vm.prank(PLAYER);
        assertEq(higherOrLower.getOwners(0), PLAYER);
    }

    //bet

    function testHigherOrLower_NotEnoughFundsToBet() public {
        vm.prank(PLAYER);
        vm.expectRevert(
            HigherOrLower.HigherOrLower_NotEnoughFundsToBet.selector
        );
        higherOrLower.bet(0);
    }

    function testHigherOrLower_TooMuchFundsToBet() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        vm.expectRevert(HigherOrLower.HigherOrLower_TooMuchFundsToBet.selector);
        higherOrLower.bet{value: 3 ether}(0);
    }

    function testHigherOrLower_IncorrectBet() public {
        vm.prank(PLAYER);
        higherOrLower.invest{value: 5 ether}();
        vm.prank(PLAYER2);
        higherOrLower.invest{value: 5 ether}();
        console2.log("max to bet", higherOrLower.getMaxtoBet());
        vm.expectRevert(HigherOrLower.HigherOrLower_IncorrectBet.selector);
        higherOrLower.bet{value: 2 ether}(6);
    }

    function testBetData_GAME_NOT_OPEN() public {
        vm.expectRevert(HigherOrLower.HigherOrLower_GAME_NOT_OPEN.selector);
        higherOrLower.bet{value: 2 ether}(0);
    }
}
