// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./SetUp.t.sol";

contract RMMInitPool is RMMSetUp {
    function test_rmm_initExactX() public {
        uint256 amountX = 5000 ether;
        (uint256 l, uint256 amountY) = rmm.initExactX(amountX, initialPrice);

        console.log("l:", l);
        console.log("amountY:", amountY);

        assertEq(rmm.totalLiquidity(), l);
        assertEq(rmm.reserveX(), amountX);
        assertEq(rmm.reserveY(), amountY);
    }

    function test_rmm_initExactY() public {
        uint256 amountY = 2000 ether;
        (uint256 l, uint256 amountX) = rmm.initExactY(amountY, 2000 ether);

        assertEq(rmm.totalLiquidity(), l);
        assertEq(rmm.reserveX(), amountX);
        assertEq(rmm.reserveY(), amountY);
    }

    function test_rmm_initExactY_UpdatesRMMBalances() public {
        uint256 amountY = 2000 ether;

        uint256 preBalanceX = tokenX.balanceOf(address(rmm));
        uint256 preBalanceY = tokenY.balanceOf(address(rmm));

        (, uint256 amountX) = rmm.initExactY(amountY, 2000 ether);

        uint256 postBalanceX = tokenX.balanceOf(address(rmm));
        uint256 postBalanceY = tokenY.balanceOf(address(rmm));

        assertEq(preBalanceX + amountX, postBalanceX);
        assertEq(preBalanceY + amountY, postBalanceY);
    }

    function test_rmm_initExactY_UpdatesSenderBalances() public {
        uint256 amountY = 2000 ether;

        uint256 preBalanceX = tokenX.balanceOf(address(this));
        uint256 preBalanceY = tokenY.balanceOf(address(this));

        (, uint256 amountX) = rmm.initExactY(amountY, 2000 ether);

        uint256 postBalanceX = tokenX.balanceOf(address(this));
        uint256 postBalanceY = tokenY.balanceOf(address(this));

        assertEq(preBalanceX - amountX, postBalanceX);
        assertEq(preBalanceY - amountY, postBalanceY);
    }
}
