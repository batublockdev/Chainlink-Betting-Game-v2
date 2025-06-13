// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {HigherOrLower} from "../src/HigherOrLower.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployHigherOrLower is Script {
    function run()
        external
        returns (
            HigherOrLower,
            HelperConfig,
            address link,
            uint256 subcriptionId,
            address coin
        )
    {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (
                config.subscriptionId,
                config.vrfCoordinatorV2_5
            ) = createSubscription.createSubscription(
                config.vrfCoordinatorV2_5,
                config.account
            );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5,
                config.subscriptionId,
                config.link,
                config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        HigherOrLower raffle = new HigherOrLower(
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5,
            config.coin
        );
        vm.stopBroadcast();

        // We already have a broadcast in here
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            config.account
        );
        return (
            raffle,
            helperConfig,
            config.link,
            config.subscriptionId,
            config.coin
        );
    }
}
