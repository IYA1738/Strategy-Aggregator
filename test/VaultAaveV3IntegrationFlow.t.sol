//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "test/VaultTestBase.t.sol";
import "contracts/Strategies/Base/IStrategyBase.sol";
import "forge-std/console2.sol";
import "contracts/Strategies/AaveV3LenderUSDC.sol";
import "contracts/External-Interface/IAaveProtocolDataProvider.sol";

contract VaultAaveV3IntegrationFlowTest is VaultTestBase {
    address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_DATA_PROVIDER = 0x0F43731EB8d45A581f4a36DD74F5f358bc90C73A;
    AaveV3LenderUSDC aaveV3LenderUSDC;

    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        aaveV3LenderUSDC = new AaveV3LenderUSDC(
            address(comptroller),
            AAVE_V3_POOL,
            AAVE_DATA_PROVIDER,
            address(agg),
            USDC
        );
        aaveV3LenderUSDC.setManager(deployer);
        vault.registryStreategy(address(aaveV3LenderUSDC));
        aaveV3LenderUSDC.setAllowedVault(address(vault), true);
        vm.stopPrank();
    }

    function test_AaveV3IntegrationFlow(uint256 _amount) external {
        uint256 userUsdcBefore = IERC20(USDC).balanceOf(user);
        // user deposit
        vm.assume(_amount > 0 && _amount <= 1000);
        vm.startPrank(user);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), _amount * 1e6);
        vm.stopPrank();

        vm.startPrank(deployer);

        // push fund to strategy
        bytes memory _data = abi.encode(_amount * 1e6);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            _amount * 1e6,
            _data
        );

        vm.stopPrank();

        //  mock time and roll block

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 900000);

        // pull fund from strategy
        vm.startPrank(deployer);
        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        uint256 vaultBal = IERC20(USDC).balanceOf(address(vault));

        assertEq(vaultBal, 0);

        _data = abi.encode(aTokenBal);

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            aTokenBal,
            _data
        );

        // vault里的钱应该比一开始多
        assertGt(IERC20(USDC).balanceOf(address(vault)), _amount * 1e6);

        (aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        assertApproxEqRel(aTokenBal, 0, 1e14);

        vm.stopPrank();

        vm.startPrank(user);

        comptroller.redeemInKind(user, address(vault), IERC20(address(vault)).balanceOf(user));

        assertGt(IERC20(USDC).balanceOf(user), _amount * 1e6);

        uint256 userUsdcAfter = IERC20(USDC).balanceOf(user);
        console2.log("user deposit       =", _amount * 1e6);
        console2.log("user USDC before =", userUsdcBefore);
        console2.log("user USDC after  =", userUsdcAfter);

        if (userUsdcAfter >= userUsdcBefore) {
            console2.log("profit (raw)     =", userUsdcAfter - userUsdcBefore);
        } else {
            console2.log("loss (raw)       =", userUsdcBefore - userUsdcAfter);
        }

        vm.stopPrank();
    }

    function test_AaveV3IntegrationFlow_ThreeUsers() external {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        deal(USDC, user1, 2_000e6);
        deal(USDC, user2, 2_000e6);
        deal(USDC, user3, 2_000e6);

        uint256 amt1 = 1_000e6;
        uint256 amt2 = 800e6;
        uint256 amt3 = 600e6;

        vm.startPrank(user1);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amt1);
        vm.stopPrank();

        vm.prank(deployer);
        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            amt1,
            abi.encode(amt1)
        );

        uint256 t0 = block.timestamp;

        vm.warp(block.timestamp + 100 days);
        vm.roll(block.number + 300_000);

        vm.startPrank(user2);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amt2);
        vm.stopPrank();

        vm.prank(deployer);
        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            amt2,
            abi.encode(amt2)
        );

        uint256 t1 = block.timestamp;

        vm.warp(block.timestamp + 100 days);
        vm.roll(block.number + 300_000);

        vm.startPrank(user3);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amt3);
        vm.stopPrank();

        vm.prank(deployer);
        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            amt3,
            abi.encode(amt3)
        );

        uint256 t2 = block.timestamp;

        vm.warp(block.timestamp + 165 days);
        vm.roll(block.number + 300_000);

        uint256 tEnd = block.timestamp;

        vm.startPrank(deployer);
        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            aTokenBal,
            abi.encode(aTokenBal)
        );
        vm.stopPrank();

        uint256 s1 = IERC20(address(vault)).balanceOf(user1);
        uint256 s2 = IERC20(address(vault)).balanceOf(user2);
        uint256 s3 = IERC20(address(vault)).balanceOf(user3);

        uint256 u1Before = IERC20(USDC).balanceOf(user1);
        uint256 u2Before = IERC20(USDC).balanceOf(user2);
        uint256 u3Before = IERC20(USDC).balanceOf(user3);

        vm.prank(user1);
        comptroller.redeemInKind(user1, address(vault), s1);

        vm.prank(user2);
        comptroller.redeemInKind(user2, address(vault), s2);

        vm.prank(user3);
        comptroller.redeemInKind(user3, address(vault), s3);

        console2.log("abs profit user1 = ", IERC20(USDC).balanceOf(user1) - 2000e6);
        console2.log("abs profit user2 = ", IERC20(USDC).balanceOf(user2) - 2000e6);
        console2.log("abs profit user3 = ", IERC20(USDC).balanceOf(user3) - 2000e6);
    }

    function test_AaveV3IntegrationFlow_SameInSameOut_DifferentPrincipal() external {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        deal(USDC, user1, 2_000e6);
        deal(USDC, user2, 2_000e6);
        deal(USDC, user3, 2_000e6);

        uint256 amt1 = 1_000e6;
        uint256 amt2 = 800e6;
        uint256 amt3 = 600e6;

        vm.startPrank(user1);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amt1);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amt2);
        vm.stopPrank();

        vm.startPrank(user3);
        IERC20(USDC).approve(address(comptroller), type(uint256).max);
        comptroller.deposit(address(vault), amt3);
        vm.stopPrank();

        uint256 t0 = block.timestamp;

        uint256 total = amt1 + amt2 + amt3;

        vm.prank(deployer);
        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.DEPLOY_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            total,
            abi.encode(total)
        );

        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 900_000);
        uint256 tEnd = block.timestamp;

        vm.startPrank(deployer);
        (uint256 aTokenBal, , , , , , , , ) = IAaveProtocolDataProvider(AAVE_DATA_PROVIDER)
            .getUserReserveData(USDC, address(aaveV3LenderUSDC));

        comptroller.interactWithStrategy(
            IStrategyBase.ActionType.HARVEST_FUND,
            address(vault),
            address(aaveV3LenderUSDC),
            aTokenBal,
            abi.encode(aTokenBal)
        );
        vm.stopPrank();

        uint256 s1 = IERC20(address(vault)).balanceOf(user1);
        uint256 s2 = IERC20(address(vault)).balanceOf(user2);
        uint256 s3 = IERC20(address(vault)).balanceOf(user3);

        vm.prank(user1);
        comptroller.redeemInKind(user1, address(vault), s1);

        vm.prank(user2);
        comptroller.redeemInKind(user2, address(vault), s2);

        vm.prank(user3);
        comptroller.redeemInKind(user3, address(vault), s3);

        uint256 p1 = IERC20(USDC).balanceOf(user1) - 2_000e6;
        uint256 p2 = IERC20(USDC).balanceOf(user2) - 2_000e6;
        uint256 p3 = IERC20(USDC).balanceOf(user3) - 2_000e6;

        console2.log("t0 =", t0);
        console2.log("tEnd =", tEnd);

        console2.log("abs profit user1(same time) =", p1);
        console2.log("abs profit user2(same time) =", p2);
        console2.log("abs profit user3(same time) =", p3);

        assertGt(p1, p2);
        assertGt(p2, p3);
    }
}
