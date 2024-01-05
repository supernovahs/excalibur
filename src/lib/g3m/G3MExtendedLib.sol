// SPDX-LICENSE-Identifier: MIT
pragma solidity ^0.8.13;

import "./G3MLib.sol";
import "solmate/tokens/ERC20.sol";

using FixedPointMathLib for uint256;
using FixedPointMathLib for int256;

function computeLGivenX(
    uint256 x,
    uint256 S,
    G3mParameters memory params
) pure returns (uint256) {
    return x.mulWadUp(params.wy.divWadUp(params.wx.mulWadUp(S)));
}

function computeLGivenY(
    uint256 y,
    uint256 S,
    G3mParameters memory params
) pure returns (uint256) {
    return y.mulWadUp(params.wx).divWadUp(params.wy.mulWadUp(S));
}

function computeXGivenL(
    uint256 L,
    uint256 S,
    G3mParameters memory params
) pure returns (uint256) {
    return params.wx.mulWadUp(L).divWadUp(params.wy.mulWadUp(S));
}

function computeYGivenL(
    uint256 L,
    uint256 S,
    G3mParameters memory params
) pure returns (uint256) {
    return params.wy.mulWadUp(L).divWadUp(params.wx.mulWadUp(S));
}

function computeInitialPoolData(
    uint256 amountX,
    uint256 initialPrice,
    G3mParameters memory params
) pure returns (bytes memory) {
    uint256 L = computeLGivenX(amountX, initialPrice, params);
    uint256 ry = computeYGivenL(L, initialPrice, params);
    L = computeNextLiquidity(amountX, ry, params);
    return abi.encode(amountX, ry, L, params);
}

function computeAllocationGivenX(
    bool add,
    uint256 amountX,
    uint256 rx,
    uint256 L
) pure returns (uint256 nextRx, uint256 nextL) {
    uint256 liquidityPerRx = L.divWadUp(rx);
    uint256 deltaL = amountX.mulWadUp(liquidityPerRx);
    nextRx = add ? rx + amountX : rx - amountX;
    nextL = add ? L + deltaL : L - deltaL;
}

function computeAllocationGivenY(
    bool add,
    uint256 amountY,
    uint256 ry,
    uint256 L
) pure returns (uint256 nextRy, uint256 nextL) {
    uint256 liquidityPerRy = L.divWadUp(ry);
    uint256 deltaL = amountY.mulWadUp(liquidityPerRy);
    nextRy = add ? ry + amountY : ry - amountY;
    nextL = add ? L + deltaL : L - deltaL;
}

/// @dev Finds the root of the swapConstant given the independent variable liquidity.
function computeNextLiquidity(
    uint256 reserveXWad,
    uint256 reserveYWad,
    G3mParameters memory params
) pure returns (uint256 L) {
    return uint256(int256(reserveXWad).powWad(int256(params.wx))).mulWadUp(
        uint256(int256(reserveYWad).powWad(int256(params.wy)))
    );
}

/// @dev Finds the root of the swapConstant given the independent variable reserveXWad.
function computeNextRy(
    uint256 reserveXWad,
    uint256 liquidity,
    G3mParameters memory params
) pure returns (uint256 ry) {
    ry = uint256(
        int256(
            liquidity.divWadUp(
                uint256(int256(reserveXWad).powWad(int256(params.wx)))
            )
        ).powWad(int256(ONE.divWadUp(params.wy)))
    );
}

/// @dev Finds the root of the swapConstant given the independent variable reserveYWad.
function computeNextRx(
    uint256 reserveYWad,
    uint256 liquidity,
    G3mParameters memory params
) pure returns (uint256 rx) {
    rx = uint256(
        int256(
            liquidity.divWadUp(
                uint256(int256(reserveYWad).powWad(int256(params.wy)))
            )
        ).powWad(int256(ONE.divWadUp(params.wx)))
    );
}
