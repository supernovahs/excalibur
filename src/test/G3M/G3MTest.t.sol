// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "../../strategies/G3M/G3M.sol";
import "../../solvers/G3M/G3MSolver.sol";
import "../../DFMM.sol";
import "../helpers/Lex.sol";

contract G3MTest is Test {
    using stdStorage for StdStorage;

    DFMM dfmm;
    G3M g3m;
    G3MSolver solver;
    address tokenX;
    address tokenY;
    Lex lex;

    uint256 public constant TEST_SWAP_FEE = 0.003 ether;

    function setUp() public {
        tokenX = address(new MockERC20("tokenX", "X", 18));
        tokenY = address(new MockERC20("tokenY", "Y", 18));
        MockERC20(tokenX).mint(address(this), 100e18);
        MockERC20(tokenY).mint(address(this), 100e18);

        lex = new Lex(tokenX, tokenY, ONE);
        dfmm = new DFMM();
        g3m = new G3M(address(dfmm));
        solver = new G3MSolver(address(g3m));

        MockERC20(tokenX).approve(address(dfmm), type(uint256).max);
        MockERC20(tokenY).approve(address(dfmm), type(uint256).max);
    }

    /// @dev Initializes a basic pool in dfmm.
    modifier basic() {
        vm.warp(0);
        G3M.G3MParams memory params = G3M.G3MParams({
            wX: 0.5 ether,
            wY: 0.5 ether,
            swapFee: TEST_SWAP_FEE,
            controller: address(0)
        });
        uint256 init_p = ONE;
        uint256 init_x = 100 ether;
        bytes memory initData =
            solver.getInitialPoolData(init_x, init_p, params);

        IDFMM.InitParams memory initParams = IDFMM.InitParams({
            strategy: address(g3m),
            tokenX: tokenX,
            tokenY: tokenY,
            data: initData
        });

        dfmm.init(initParams);
        _;
    }

    function test_g3m_swap() public basic {
      uint256 amountIn = 10 ether;
      uint256 poolId = dfmm.nonce() - 1;
      (bool valid, uint256 amountOut, uint256 price, bytes memory swapData) = solver.simulateSwap(poolId, true, amountIn);
    }

    // function test_internal_price() public basic {
    //     uint256 internalPrice = solver.internalPrice();

    //     console2.log(internalPrice);
    // }

    // function test_internal_price_post_y_in() public basic {
    //     uint256 internalPrice = solver.internalPrice();
    //     uint256 amountIn = 0.1 ether;
    //     bool swapXIn = false;

    //     // Try doing simulate swap to see if we get a similar result.
    //     (bool valid,,, bytes memory payload) =
    //         solver.simulateSwap(swapXIn, amountIn);

    //     assertEq(valid, true);

    //     dfmm.swap(payload);

    //     uint256 postSwapInternalPrice = solver.internalPrice();

    //     assertGt(postSwapInternalPrice, internalPrice);
    // }

    // function test_internal_price_post_x_in() public basic {
    //     uint256 internalPrice = solver.internalPrice();
    //     uint256 amountIn = 0.1 ether;
    //     bool swapXIn = true;

    //     // Try doing simulate swap to see if we get a similar result.
    //     (bool valid,,, bytes memory payload) =
    //         solver.simulateSwap(swapXIn, amountIn);

    //     assertEq(valid, true);

    //     dfmm.swap(payload);

    //     uint256 postSwapInternalPrice = solver.internalPrice();

    //     assertLt(postSwapInternalPrice, internalPrice);
    // }
}
