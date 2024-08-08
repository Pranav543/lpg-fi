// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MessageSender} from "../src/ccip/Sender.sol";
import {MessageReceiver} from "../src/ccip/Receiver.sol";
import {LPG} from "../src/LPG.sol";
import {LPGSource} from "../src/LPGSource.sol";
import {LPGDestination} from "../src/LPGDestination.sol";
import {ChainConfig} from "./ChainConfig.s.sol";

contract Deploy_LPG is Script, ChainConfig {
    address[] public collateralAddresses;
    address[] public priceFeedAddresses;
    uint64[] public chainSelectors;
    address[] public messageReceivers;

    function run() external returns (LPG _LPG, HelperConfig _helperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address daiUsdPriceFeed,
            address crudeOilUsdPriceFeed,
            address ccipRouter,
            address weth,
            address dai,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        collateralAddresses = [weth, dai];
        priceFeedAddresses = [wethUsdPriceFeed, daiUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        if (block.chainid == OPTIMISM_SEPOLIA_CHAIN_ID) {
            return deployOptimismSepolia(helperConfig, crudeOilUsdPriceFeed, ccipRouter);
        }

        if (block.chainid == MODE_SEPOLIA_CHAIN_ID || block.chainid == BASE_SEPOLIA_CHAIN_ID) {
            return deployDestinationChains(helperConfig, ccipRouter);
        }

        if (block.chainid == ANVIL_CHAIN_ID) {
            return deployAnvil(helperConfig, crudeOilUsdPriceFeed);
        }

        vm.stopBroadcast();
    }

    function deployOptimismSepolia(HelperConfig helperConfig, address crudeOilUsdPriceFeed, address ccipRouter)
        internal
        returns (LPGSource, HelperConfig)
    {
        (
            uint64 baseSepoliaChainSelector,
            uint64 modeSepoliaChainSelector,
            address baseSepoliaReceiver,
            address modeSepoliaReceiver
        ) = helperConfig.destinationChainConfig();
        MessageSender messageSender = new MessageSender(ccipRouter);
        address payable messageSenderAddress = payable(address(messageSender));

        chainSelectors = [baseSepoliaChainSelector, modeSepoliaChainSelector];
        messageReceivers = [baseSepoliaReceiver, modeSepoliaReceiver];
        LPGSource LPG = new LPGSource(
            crudeOilUsdPriceFeed,
            messageSenderAddress,
            collateralAddresses,
            priceFeedAddresses,
            chainSelectors,
            messageReceivers
        );
        vm.stopBroadcast();
        return (LPG, helperConfig);
    }

    function deployDestinationChains(HelperConfig helperConfig, address ccipRouter)
        internal
        returns (LPG, HelperConfig)
    {
        MessageReceiver messageReceiver = new MessageReceiver(ccipRouter);
        address messageReceiverAddress = address(messageReceiver);

        LPGDestination LPG = new LPGDestination(messageReceiverAddress, collateralAddresses, priceFeedAddresses);
        vm.stopBroadcast();
        return (LPG, helperConfig);
    }

    function deployAnvil(HelperConfig helperConfig, address crudeOilUsdPriceFeed)
        internal
        returns (LPG, HelperConfig)
    {
        LPG LPG = new LPG(crudeOilUsdPriceFeed, collateralAddresses, priceFeedAddresses);
        vm.stopBroadcast();
        return (LPG, helperConfig);
    }
}
