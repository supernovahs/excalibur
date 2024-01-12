// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SetUp.sol";

contract LogNormalInitTest is LogNormalSetUp {
    function test_LOG_NORMAL_init_StoresPoolParameters() public init {
        (
            bool inited,
            address controller,
            address strategy,
            address tokenX,
            address tokenY,
            uint256 reserveX,
            uint256 reserveY,
            uint256 totalLiquidity,
            uint256 feeGrowth
        ) = dfmm.pools(POOL_ID);

        assertEq(inited, true);
        assertEq(controller, address(this));
        assertEq(strategy, address(logNormal));
        assertEq(tokenX, address(tokenX));
        assertEq(tokenY, address(tokenY));
        assertEq(reserveX, defaultReserveX);
        assertEq(reserveY, reserveY);
        assertEq(totalLiquidity, totalLiquidity);
        assertEq(feeGrowth, FixedPointMathLib.WAD);
    }

    function test_LOG_NORMAL_init_RevertsIfInvalidTokens() public {
        IMultiCore.InitParams memory initParams = IMultiCore.InitParams({
            strategy: address(logNormal),
            tokenX: address(tokenX),
            tokenY: address(tokenX),
            data: defaultInitialPoolData
        });

        vm.expectRevert(IMultiCore.InvalidTokens.selector);
        dfmm.init(initParams);
    }
}
