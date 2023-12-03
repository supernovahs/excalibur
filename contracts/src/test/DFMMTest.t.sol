// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../v3/BisectionLib.sol";
import "../v3/DFMM.sol";
import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

contract DFMMTest is Test {
    LogNormal source;
    DFMM dfmm;
    address tokenX;
    address tokenY;

    uint256 public constant SWAP_FEE = 0.01e18;

    function findLiquidity(
        uint256 reserveX,
        uint256 reserveY,
        Parameters memory params
    ) public view returns (uint256 liquidity) {
        uint256 lower = reserveX + 1;
        uint256 upper = 1e35;
        int256 invariant_start = 0;
        liquidity = bisection(
            abi.encode(reserveX, reserveY, invariant_start, params),
            lower,
            upper,
            1,
            256,
            findRootLiquidity
        );
    }

    function setUp() public {
        source = new LogNormal(SWAP_FEE);
        tokenX = address(new MockERC20("tokenX", "X", 18));
        tokenY = address(new MockERC20("tokenY", "Y", 18));
        MockERC20(tokenX).mint(address(this), 1e18);
        MockERC20(tokenY).mint(address(this), 1e18);

        dfmm = new DFMM(tokenX, tokenY);
        MockERC20(tokenX).approve(address(dfmm), type(uint256).max);
        MockERC20(tokenY).approve(address(dfmm), type(uint256).max);
    }

    function test_mulWadDownInt() public {
        int256 a = 1e18;
        int256 b = 1e18;
        uint256 c = uint256(source.mulWadDownInt(a, b));
        assertEq(c, 1e18);
    }

    function test_mulWadDownInt_revert_overflow() public {
        int256 a = 1e18;
        int256 b = type(int256).max;
        vm.expectRevert();
        source.mulWadDownInt(a, b);
    }

    /// @dev Initializes a basic pool in dfmm.
    modifier basic() {
        Parameters memory params = Parameters({
            strikePriceWad: 1e18,
            sigmaPercentWad: 1e18,
            tauYearsWad: 1e18
        });
        uint256 init_p = 1.0e18;
        uint256 init_x = 0.5e18;
        uint256 init_l = LogNormal(source).lx(init_x, init_p, params);
        uint256 init_y = LogNormal(source).yl(init_l, init_p, params);
        uint256 found_l = findLiquidity(init_x, init_y, params);

        bytes memory init_data =
            LogNormal(source).encode(init_x, init_y, found_l, params);

        dfmm.init(address(source), init_data);

        _;
    }

    function test_dfmm_init() public {
        Parameters memory params = Parameters({
            strikePriceWad: 1e18,
            sigmaPercentWad: 1e18,
            tauYearsWad: 1e18
        });
        uint256 init_p = 1.0e18;
        uint256 init_x = 0.5e18;

        // note: adding 2 wei to the d1 value before calling cdf with these values will result in 0.5e18 y reserves...
        // actually adding 1 wei to d2 in the y given l computation also yields 0.5e18 y reserves.
        int256 d1 = LogNormal(source).computeD1(init_p, params);
        console2.logInt(d1);
        int256 cdfOfD1 = Gaussian.cdf(d1);
        console2.logInt(cdfOfD1);

        uint256 init_l = LogNormal(source).lx(init_x, init_p, params);
        uint256 init_y = LogNormal(source).yl(init_l, init_p, params);
        console2.log("init_l", init_l);
        console2.log("init_y", init_y);
        uint256 found_l = findLiquidity(init_x, init_y, params);
        console2.log("found_l", found_l);

        // This computation is slightly off (invariant won't be zero).
        bytes memory init_data =
            LogNormal(source).encode(init_x, init_y, found_l, params);

        console2.log("init_x", init_x);
        console2.log("init_y", init_y);
        console2.log("init_l", init_l);

        console2.log(MockERC20(tokenX).balanceOf(address(this)));
        console2.log(MockERC20(tokenY).balanceOf(address(this)));

        (uint256 x, uint256 y, uint256 l) =
            dfmm.init(address(source), init_data);
        console2.log("x", x);
        console2.log("y", y);
        console2.log("l", l);

        assertEq(x, init_x, "x != init x");
        assertEq(y, init_y, "y != init y");
        assertEq(l, found_l, "l != found l");
        assertEq(dfmm.balanceOf(address(this)), found_l, "l != found l");
        assertTrue(dfmm.inited(), "not initialized!");
        assertEq(
            MockERC20(tokenX).balanceOf(address(dfmm)),
            init_x,
            "x balance != init x"
        );
        assertEq(
            MockERC20(tokenY).balanceOf(address(dfmm)),
            init_y,
            "y balance != init y"
        );
    }

    function test_dfmm_swap() public basic {
        uint256 feePercentageWad = source.swapFeePercentageWad();

        // Get all the current data: reserves, liquidity, invariant, params.
        int256 invariant = dfmm.magicConstant(address(source));
        console2.logInt(invariant);

        (uint256 reserveXWad, uint256 reserveYWad, uint256 liquidity) =
            dfmm.getReservesAndLiquidity();

        console2.log("reserveXWad", reserveXWad);
        console2.log("reserveYWad", reserveYWad);
        console2.log("liquidity", liquidity);

        Parameters memory params;
        (params.strikePriceWad, params.sigmaPercentWad, params.tauYearsWad) =
            source.slot();

        // todo: should take this out.
        uint256 price = 1.0e18;

        // Compute the adjusted x reserve and adjusted liquidity.
        uint256 amountXIn = 0.1 ether;
        console2.log("swap in", amountXIn);

        uint256 adjustedReserveX = reserveXWad + amountXIn;
        console2.log("Submitted new X reserve", adjustedReserveX);

        uint256 expectedLiquidityGrowth =
            source.lx(amountXIn * feePercentageWad / 1 ether, price, params);
        console2.log("expectedLiquidityGrowth", expectedLiquidityGrowth);

        // So we compute the adjusted liquidity amount to find the y, but pass in the origina liquidity.
        // So we need the contract to validate the expected growth.
        uint256 adjustedLiquidity = liquidity + expectedLiquidityGrowth;
        console2.log("Submitted new liquidity", adjustedLiquidity);

        uint256 adjustedReserveY =
            findY(adjustedReserveX, adjustedLiquidity, invariant, params);
        console2.log("Submitted new Y reserve", adjustedReserveY);

        // Increase the adjusted y reserve by a "rounding espilon". This reduces the amount out,
        // and ensures we pass the invariant check.
        adjustedReserveY += 1;

        uint256 amountYOut = reserveYWad - adjustedReserveY;
        console2.log("amountYOut", amountYOut);

        // Try doing the swap with the adjusted reserves.
        bytes memory swapData =
            abi.encode(adjustedReserveX, adjustedReserveY, adjustedLiquidity);

        dfmm.swap(address(source), swapData);
    }
}

function findY(
    uint256 reserveX,
    uint256 liquidity,
    int256 invariant,
    Parameters memory params
) view returns (uint256 reserveY) {
    uint256 lower = 100;
    uint256 upper = params.strikePriceWad - 1;
    reserveY = bisection(
        abi.encode(reserveX, liquidity, invariant, params),
        lower,
        upper,
        1,
        256,
        findRootY
    );
}
