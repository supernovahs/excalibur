// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "src/interfaces/IDFMM.sol";
import "src/interfaces/IStrategy.sol";
import "src/lib/DynamicParamLib.sol";
import "src/lib/StrategyLib.sol";
import "./LogNormalLib.sol";

/// @notice Log Normal has three variable parameters:
/// K - strike price
/// sigma - volatility
/// tau - time to expiry
///
/// Swaps are validated by the trading function:
/// Gaussian.ppf(x / L) + Gaussian.ppf(y / KL) = -sigma * sqrt(tau)
contract LogNormal is IStrategy {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;
    using DynamicParamLib for DynamicParam;

    struct InternalParams {
        DynamicParam sigma;
        DynamicParam tau;
        DynamicParam strike;
        uint256 swapFee;
        address controller;
    }

    /// @dev Parameterization of the Log Normal curve.
    struct LogNormalParams {
        uint256 strike;
        uint256 sigma;
        uint256 tau;
        uint256 swapFee;
        address controller;
    }

    /// @inheritdoc IStrategy
    address public dfmm;

    mapping(uint256 => InternalParams) public internalParams;

    /// @param dfmm_ Address of the DFMM contract.
    constructor(address dfmm_) {
        dfmm = dfmm_;
    }

    modifier onlyDFMM() {
        if (msg.sender != dfmm) revert NotDFMM();
        _;
    }

    /// @inheritdoc IStrategy
    function init(
        address,
        uint256 poolId,
        bytes calldata data
    )
        public
        onlyDFMM
        returns (
            bool valid,
            int256 invariant,
            uint256 reserveX,
            uint256 reserveY,
            uint256 totalLiquidity
        )
    {
        (valid, invariant, reserveX, reserveY, totalLiquidity,) =
            _decodeInit(poolId, data);
    }

    /// @dev Decodes, stores and validates pool initialization parameters.
    /// Note that this function was purely made to avoid the stack too deep
    /// error in the `init()` function.
    function _decodeInit(
        uint256 poolId,
        bytes calldata data
    )
        private
        returns (
            bool valid,
            int256 invariant,
            uint256 reserveX,
            uint256 reserveY,
            uint256 totalLiquidity,
            LogNormalParams memory params
        )
    {
        (reserveX, reserveY, totalLiquidity, params) =
            abi.decode(data, (uint256, uint256, uint256, LogNormalParams));

        internalParams[poolId].sigma.lastComputedValue = params.sigma;
        internalParams[poolId].tau.lastComputedValue = params.tau;
        internalParams[poolId].strike.lastComputedValue = params.strike;
        internalParams[poolId].swapFee = params.swapFee;
        internalParams[poolId].controller = params.controller;

        invariant = tradingFunction(
            reserveX,
            reserveY,
            totalLiquidity,
            abi.decode(getPoolParams(poolId), (LogNormalParams))
        );
        // todo: should the be EXACTLY 0? just positive? within an epsilon?
        valid = -(EPSILON) < invariant && invariant < EPSILON;
    }

    /// @inheritdoc IStrategy
    function validateAllocateOrDeallocate(
        address,
        uint256 poolId,
        bytes calldata data
    )
        public
        view
        returns (
            bool valid,
            int256 invariant,
            uint256 reserveX,
            uint256 reserveY,
            uint256 totalLiquidity
        )
    {
        (reserveX, reserveY, totalLiquidity) =
            abi.decode(data, (uint256, uint256, uint256));

        invariant = tradingFunction(
            reserveX,
            reserveY,
            totalLiquidity,
            abi.decode(getPoolParams(poolId), (LogNormalParams))
        );

        valid = -(EPSILON) < invariant && invariant < EPSILON;
    }

    /// @inheritdoc IStrategy
    function validateSwap(
        address,
        uint256 poolId,
        bytes memory data
    )
        public
        view
        returns (
            bool valid,
            int256 invariant,
            int256 liquidityDelta,
            uint256 nextRx,
            uint256 nextRy,
            uint256 nextL
        )
    {
        LogNormalParams memory params =
            abi.decode(getPoolParams(poolId), (LogNormalParams));

        (uint256 startRx, uint256 startRy, uint256 startL) =
            IDFMM(dfmm).getReservesAndLiquidity(poolId);

        (nextRx, nextRy, nextL) = abi.decode(data, (uint256, uint256, uint256));

        // Rounding up is advantageous towards the protocol, to make sure swap fees
        // are fully paid for.
        uint256 minLiquidityDelta;
        uint256 amountIn;
        uint256 fees;
        if (nextRx > startRx) {
            amountIn = nextRx - startRx;
            fees = amountIn.mulWadUp(params.swapFee);
            minLiquidityDelta += fees.mulWadUp(startL).divWadUp(startRx);
        } else if (nextRy > startRy) {
            // δl = δx * L / X, where δx = delta x * fee
            amountIn = nextRy - startRy;
            fees = amountIn.mulWadUp(params.swapFee);
            minLiquidityDelta += fees.mulWadUp(startL).divWadUp(startRy);
        } else {
            // should never get here!
            revert("invalid swap: inputs x and y have the same sign!");
        }

        liquidityDelta = int256(nextL) - int256(startL);

        invariant = tradingFunction(nextRx, nextRy, nextL, params);
        valid = -(EPSILON) < invariant && invariant < EPSILON;
    }

    /// @inheritdoc IStrategy
    function update(
        address sender,
        uint256 poolId,
        bytes calldata data
    ) external onlyDFMM {
        if (sender != internalParams[poolId].controller) revert InvalidSender();
        LogNormalUpdateCode updateCode = abi.decode(data, (LogNormalUpdateCode));

        if (updateCode == LogNormalUpdateCode.SwapFee) {
            internalParams[poolId].swapFee = decodeFeeUpdate(data);
        } else if (updateCode == LogNormalUpdateCode.Sigma) {
            (uint256 targetSigma, uint256 targetTimestamp) =
                decodeSigmaUpdate(data);
            internalParams[poolId].sigma.set(targetSigma, targetTimestamp);
        } else if (updateCode == LogNormalUpdateCode.Tau) {
            (uint256 targetTau, uint256 targetTimestamp) = decodeTauUpdate(data);
            internalParams[poolId].tau.set(targetTau, targetTimestamp);
        } else if (updateCode == LogNormalUpdateCode.Strike) {
            (uint256 targetStrike, uint256 targetTimestamp) =
                decodeStrikeUpdate(data);
            internalParams[poolId].strike.set(targetStrike, targetTimestamp);
        } else if (updateCode == LogNormalUpdateCode.Controller) {
            internalParams[poolId].controller = decodeControllerUpdate(data);
        } else {
            revert InvalidUpdateCode();
        }
    }

    /// @inheritdoc IStrategy
    function getPoolParams(uint256 poolId) public view returns (bytes memory) {
        LogNormalParams memory params;

        params.sigma = internalParams[poolId].sigma.actualized();
        params.strike = internalParams[poolId].strike.actualized();
        params.tau = internalParams[poolId].tau.actualized();
        params.swapFee = internalParams[poolId].swapFee;

        return abi.encode(params);
    }

    /// @inheritdoc IStrategy
    function computeSwapConstant(
        uint256 poolId,
        bytes memory data
    ) public view returns (int256) {
        (uint256 reserveX, uint256 reserveY, uint256 totalLiquidity) =
            abi.decode(data, (uint256, uint256, uint256));
        return tradingFunction(
            reserveX,
            reserveY,
            totalLiquidity,
            abi.decode(getPoolParams(poolId), (LogNormalParams))
        );
    }
}
