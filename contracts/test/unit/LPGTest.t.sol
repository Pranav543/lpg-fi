// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {Deploy_LPG, HelperConfig} from "../../script/Deploy_LPG.s.sol";
import {LPG, AggregatorV3Interface} from "../../src/LPG.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract LPGTest is Test {
    LPG LPGInstance;
    HelperConfig helperConfig;

    address wethUsdPriceFeed;
    address daiUsdPriceFeed;
    address crudeOilUsdPriceFeed;
    address weth;
    address dai;
    uint256 deployerKey;

    address user = makeAddr("User");
    address liquidator = makeAddr("Liquidator");

    uint256 constant STARTING_DAI_BALANCE = 75e18;
    uint256 constant STARTING_WETH_BALANCE = 0.025 ether;
    uint256 constant MINT_OIL_AMOUNT = 1e10;
    uint256 constant HALF_MINT_OIL_AMOUNT = 0.5e18;

    function setUp() public {
        Deploy_LPG deployer = new Deploy_LPG();
        (LPGInstance, helperConfig) = deployer.run();
        (wethUsdPriceFeed, daiUsdPriceFeed, crudeOilUsdPriceFeed,, weth, dai, deployerKey) =
            helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_WETH_BALANCE);
        ERC20Mock(dai).mint(user, STARTING_DAI_BALANCE);
    }

    modifier depositAndMint() {
        vm.startPrank(user);
        // deposit weth and mint oil
        ERC20Mock(weth).approve(address(LPGInstance), STARTING_WETH_BALANCE);
        LPGInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        ERC20Mock(dai).approve(address(LPGInstance), STARTING_DAI_BALANCE);
        LPGInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        vm.stopPrank();
        _;
    }

    modifier depositAndMintHalf() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(LPGInstance), STARTING_WETH_BALANCE);
        LPGInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        ERC20Mock(dai).approve(address(LPGInstance), STARTING_DAI_BALANCE);
        LPGInstance.depositCollateral(dai, STARTING_DAI_BALANCE);
        vm.stopPrank();
        _;
    }

    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(wethUsdPriceFeed);
        feedAddresses.push(daiUsdPriceFeed);

        vm.expectRevert(LPG.LPG__CollateralAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new LPG(crudeOilUsdPriceFeed, tokenAddresses, feedAddresses);
    }

    function test_depositWethAndMint() public {
        // Arrange
        vm.startPrank(user);

        // Act
        ERC20Mock(weth).approve(address(LPGInstance), STARTING_WETH_BALANCE);
        LPGInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        // Assert
        assertEq(LPGInstance.s_collateralPerUser(user, weth), STARTING_WETH_BALANCE);
        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWethAndMintTransferFailed() public {
        vm.startPrank(user);
        vm.expectRevert();
        LPGInstance.depositAndMint(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWethAndMintBrokenHealthFactor() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(LPGInstance), STARTING_WETH_BALANCE);
        vm.expectRevert();
        LPGInstance.depositAndMint(weth, STARTING_WETH_BALANCE / 2, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositDaiAndMint() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(LPGInstance), STARTING_DAI_BALANCE);
        LPGInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(LPGInstance.s_collateralPerUser(user, dai), STARTING_DAI_BALANCE);
        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositDaiAndMintTransferFailed() public {
        vm.startPrank(user);
        vm.expectRevert();
        LPGInstance.depositAndMint(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_depositWeth() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(LPGInstance), STARTING_WETH_BALANCE);
        LPGInstance.depositCollateral(weth, STARTING_WETH_BALANCE);

        assertEq(LPGInstance.s_collateralPerUser(user, weth), STARTING_WETH_BALANCE);
        assertEq(LPGInstance.s_oilMintedPerUser(user), 0);
        vm.stopPrank();
    }

    function test_depositDai() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(LPGInstance), STARTING_DAI_BALANCE);
        LPGInstance.depositCollateral(dai, STARTING_DAI_BALANCE);

        assertEq(LPGInstance.s_collateralPerUser(user, dai), STARTING_DAI_BALANCE);
        vm.stopPrank();
    }

    function test_mintOil() public {
        vm.startPrank(user);
        ERC20Mock(dai).approve(address(LPGInstance), STARTING_DAI_BALANCE);
        LPGInstance.depositCollateral(dai, STARTING_DAI_BALANCE);
        LPGInstance.mintOil(HALF_MINT_OIL_AMOUNT);

        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurn() public depositAndMint {
        vm.startPrank(user);
        LPGInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurnTransferFailed() public depositAndMint {
        vm.startPrank(user);
        vm.expectRevert();
        LPGInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE * 2, HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemWethAndBurnHealthFactorBroken() public depositAndMint {
        vm.startPrank(user);
        vm.expectRevert();
        LPGInstance.redeemAndBurn(weth, STARTING_WETH_BALANCE, HALF_MINT_OIL_AMOUNT * 4);
        vm.stopPrank();
    }

    function test_redeemDaiAndBurn() public depositAndMint {
        vm.startPrank(user);
        LPGInstance.redeemAndBurn(dai, STARTING_DAI_BALANCE, HALF_MINT_OIL_AMOUNT);

        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_burn() public depositAndMint {
        vm.startPrank(user);
        uint256 startingHealthFactor = LPGInstance.getHealthFactor(user);
        LPGInstance.burn(HALF_MINT_OIL_AMOUNT);
        uint256 finishingHealthFactor = LPGInstance.getHealthFactor(user);

        assertEq(startingHealthFactor, 1.005e18);
        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        assertEq(finishingHealthFactor, 2.01e18);
        vm.stopPrank();
    }

    function test_redeemWeth() public depositAndMintHalf {
        vm.startPrank(user);
        LPGInstance.redeem(weth, STARTING_WETH_BALANCE);

        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_redeemDai() public depositAndMintHalf {
        vm.startPrank(user);
        LPGInstance.redeem(dai, STARTING_DAI_BALANCE);

        assertEq(LPGInstance.s_oilMintedPerUser(user), HALF_MINT_OIL_AMOUNT);
        assertEq(LPGInstance.balanceOf(user), HALF_MINT_OIL_AMOUNT);
        vm.stopPrank();
    }

    function test_liquidate() public depositAndMint {
        ERC20Mock(weth).mint(liquidator, STARTING_WETH_BALANCE * 4);
        ERC20Mock(dai).mint(liquidator, STARTING_DAI_BALANCE * 4);

        vm.startPrank(liquidator);
        // deposit weth and mint oil
        ERC20Mock(weth).approve(address(LPGInstance), STARTING_WETH_BALANCE * 4);
        LPGInstance.depositAndMint(weth, STARTING_WETH_BALANCE * 4, HALF_MINT_OIL_AMOUNT * 2);
        // deposit dai and mint oil
        ERC20Mock(dai).approve(address(LPGInstance), STARTING_DAI_BALANCE * 4);
        LPGInstance.depositAndMint(dai, STARTING_DAI_BALANCE * 4, HALF_MINT_OIL_AMOUNT * 2);

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(2500e8);

        // liquidate
        LPGInstance.liquidate(user, weth, HALF_MINT_OIL_AMOUNT);
        uint256 userHealthFactor = LPGInstance.getHealthFactor(user);
        console2.log("Health Factor: %s", userHealthFactor);
        assert(userHealthFactor > 1e18);
        vm.stopPrank();
    }

    function test_getHealthFactor() public depositAndMint {
        // Arrange
        vm.startPrank(user);
        // Act
        uint256 healthFactor = LPGInstance.getHealthFactor(user);
        vm.stopPrank();
        // Assert
        assertEq(healthFactor, 1.005e18);
    }

    function test_getUsdAmountFromOil() public view {
        uint256 oilAmount = 1e18;
        uint256 usdAmount = LPGInstance.getUsdAmountFromOil(oilAmount);
        assertEq(usdAmount, 100e18);
    }

    function test_getUsdAmountFromWeth() public view {
        uint256 ethAmount = 1e18;
        uint256 usdAmount = LPGInstance.getUsdAmountFromToken(weth, ethAmount);
        assertEq(usdAmount, 3000e18);
    }

    function test_getUsdAmountFromDai() public view {
        uint256 daiAmount = 1e18;
        uint256 usdAmount = LPGInstance.getUsdAmountFromToken(dai, daiAmount);
        assertEq(usdAmount, 1e18);
    }

    function test_getWethAmountFromUsd() public view {
        uint256 usdAmount = 75e18;
        uint256 ethAmount = LPGInstance.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(ethAmount, 0.025e18);
    }

    function test_getDaiAmountFromUsd() public view {
        uint256 usdAmount = 75e18;
        uint256 daiAmount = LPGInstance.getTokenAmountFromUsd(dai, usdAmount);
        assertEq(daiAmount, 75e18);
    }

    function test_getAccountInformationValue() public depositAndMint {
        vm.startPrank(user);
        (uint256 totalOilMintedValueInUsd, uint256 totalCollateralValueUsd) =
            LPGInstance.getAccountInformationValue(user);
        vm.stopPrank();

        assertEq(totalOilMintedValueInUsd, 100e18);
        assertEq(totalCollateralValueUsd, 150e18);
    }
}
