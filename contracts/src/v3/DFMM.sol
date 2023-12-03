// SPDX-LICENSE-Identifier: MIT
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "solstat/Gaussian.sol";
import "forge-std/console2.sol";

struct Parameters {
    uint256 strikePriceWad;
    uint256 sigmaPercentWad;
    uint256 tauYearsWad;
}

uint256 constant SQRT_WAD = 1e9;

function findRootX(
    bytes memory data,
    uint256 reserveXWad
) pure returns (int256) {
    (uint256 liquidity, uint256 y, int256 invariant, Parameters memory params) =
        abi.decode(data, (uint256, uint256, int256, Parameters));
    // todo: maybe update with difference with previous invariant.
    return tradingFunction({
        reserveXWad: reserveXWad,
        reserveYWad: y,
        totalLiquidity: liquidity,
        params: params
    }) - invariant;
}

function findRootY(
    bytes memory data,
    uint256 reserveYWad
) pure returns (int256) {
    (uint256 x, uint256 liquidity, int256 invariant, Parameters memory params) =
        abi.decode(data, (uint256, uint256, int256, Parameters));
    // todo: maybe update with difference with previous invariant.
    return tradingFunction({
        reserveXWad: x,
        reserveYWad: reserveYWad,
        totalLiquidity: liquidity,
        params: params
    }) - invariant;
}

function findRootLiquidity(
    bytes memory data,
    uint256 liquidity
) pure returns (int256) {
    (uint256 x, uint256 y, int256 invariant, Parameters memory params) =
        abi.decode(data, (uint256, uint256, int256, Parameters));
    // todo: maybe update with difference with previous invariant.
    return tradingFunction({
        reserveXWad: x,
        reserveYWad: y,
        totalLiquidity: liquidity,
        params: params
    }) - invariant;
}

/// @param sigmaPercentWad Must be in WAD units such that 1E18 = 100%.
/// @param tauYearsWad Must be in WAD units such that 1E18 = 1 year.
/// @return sigmaSqrtTau The product of sigma and the square root of tau in WAD units.
function computeSigmaSqrtTau(
    uint256 sigmaPercentWad,
    uint256 tauYearsWad
) pure returns (uint256) {
    // Sqrt will return a value in 1E9 units.
    uint256 sqrtTauNotWad = FixedPointMathLib.sqrt(tauYearsWad);
    // Normalize it back to WAD units.
    uint256 sqrtTauWad = sqrtTauNotWad * SQRT_WAD;
    // Find the product of the WAD values.
    return FixedPointMathLib.mulWadDown(sigmaPercentWad, sqrtTauWad);
}

/// @param reserveXWad Total quantity of X tokens in the pool, in WAD units.
/// @param reserveYWad Total quantity of Y tokens in the pool, in WAD units.
/// @param totalLiquidity Total liquidity in the pool, in WAD units.
/// @param params Parameters of the Log Normal distribution.
/// @return int256 Gaussian.ppf(x / L) + Gaussian.ppf(y / KL) + sigma * sqrt(tau)
function tradingFunction(
    uint256 reserveXWad,
    uint256 reserveYWad,
    uint256 totalLiquidity,
    Parameters memory params
) pure returns (int256) {
    require(reserveXWad < totalLiquidity, "tradingFunction: invalid x");
    int256 part_0 = Gaussian.ppf(
        int256(FixedPointMathLib.divWadDown(reserveXWad, totalLiquidity))
    );

    int256 part_1 = Gaussian.ppf(
        int256(
            FixedPointMathLib.divWadDown(
                reserveYWad,
                FixedPointMathLib.mulWadDown(
                    params.strikePriceWad, totalLiquidity
                )
            )
        )
    );

    int256 part_2 = int256(
        computeSigmaSqrtTau({
            sigmaPercentWad: params.sigmaPercentWad,
            tauYearsWad: params.tauYearsWad
        })
    );

    return part_0 + part_1 + part_2;
}

interface Source {
    function init(bytes calldata data)
        external
        returns (
            bool valid,
            int256 difference,
            uint256 reserveXWad,
            uint256 reserveYWad,
            uint256 totalLiquidity
        );

    function validate(bytes calldata data)
        external
        view
        returns (
            bool valid,
            int256 difference,
            uint256 reserveXWad,
            uint256 reserveYWad,
            uint256 totalLiquidity
        );
}

interface Core {
    function getReservesAndLiquidity()
        external
        view
        returns (
            uint256 reserveXWad,
            uint256 reserveYWad,
            uint256 totalLiquidity
        );
}

/// @notice Log Normal has three variable parameters:
/// K - strike price
/// sigma - volatility
/// tau - time to expiry
///
/// Swaps are validated by the trading function:
/// Gaussian.ppf(x / L) + Gaussian.ppf(y / KL) = -sigma * sqrt(tau)
contract LogNormal {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    uint256 public constant HALF_WAD = 0.5e18;
    int256 public constant TWO_WAD = int256(2e18);

    uint256 public constant WAD = 1e18;
    uint256 public constant ZERO = 0;

    constructor(uint256 swapFeePercentageWad_) {
        swapFeePercentageWad = swapFeePercentageWad_;
    }

    uint256 public swapFeePercentageWad;

    Parameters public slot;

    function encode(
        uint256 reserveXWad,
        uint256 reseveYWad,
        uint256 totalLiquidity,
        Parameters memory params
    ) public pure returns (bytes memory) {
        return abi.encode(reserveXWad, reseveYWad, totalLiquidity, params);
    }

    function magicConstant(bytes calldata data) public view returns (int256) {
        (uint256 reserveXWad, uint256 reserveYWad, uint256 totalLiquidity) =
            abi.decode(data, (uint256, uint256, uint256));
        return tradingFunction({
            reserveXWad: reserveXWad,
            reserveYWad: reserveYWad,
            totalLiquidity: totalLiquidity,
            params: slot
        });
    }

    /// @dev Decodes and validates pool initialization parameters.
    function init(bytes calldata data)
        public
        returns (
            bool valid,
            int256 difference,
            uint256 reserveXWad,
            uint256 reserveYWad,
            uint256 totalLiquidity
        )
    {
        (reserveXWad, reserveYWad, totalLiquidity, slot) =
            abi.decode(data, (uint256, uint256, uint256, Parameters));

        difference = tradingFunction({
            reserveXWad: reserveXWad,
            reserveYWad: reserveYWad,
            totalLiquidity: totalLiquidity,
            params: slot
        });

        // todo: should the be EXACTLY 0? just positive? within an epsilon?
        valid = difference >= (int256(ZERO) + 3);
    }

    function validate(bytes calldata data)
        public
        view
        returns (
            bool valid,
            int256 difference,
            uint256 adjustedReserveXWad,
            uint256 adjustedReserveYWad,
            uint256 adjustedLiquidity
        )
    {
        (
            uint256 originalReserveXWad,
            uint256 originalReserveYWad,
            uint256 originalLiquidity
        ) = Core(msg.sender).getReservesAndLiquidity();

        (adjustedReserveXWad, adjustedReserveYWad, adjustedLiquidity) =
            abi.decode(data, (uint256, uint256, uint256));

        // lambda l = lambda x * L / X, where lamba x = delta x * (1 - fee)

        // x for now, do y next
        uint256 amountIn = adjustedReserveXWad - originalReserveXWad;
        uint256 fees = amountIn.mulWadDown(swapFeePercentageWad);
        uint256 deltaL =
            fees.mulWadDown(originalLiquidity).divWadDown(originalReserveXWad);

        uint256 liquidityDelta = adjustedLiquidity - originalLiquidity;
        console2.log("Submitted liquidity delta", liquidityDelta);
        console2.log("Min valid liquidity delta", deltaL);
        console2.log("liquidityDelta - deltaL", liquidityDelta - deltaL);
        console2.log(liquidityDelta, deltaL);
        require(liquidityDelta >= deltaL, "invalid liquidity delta");

        difference = tradingFunction({
            reserveXWad: adjustedReserveXWad,
            reserveYWad: adjustedReserveYWad,
            totalLiquidity: adjustedLiquidity,
            params: slot
        })
            - tradingFunction({
                reserveXWad: originalReserveXWad,
                reserveYWad: originalReserveYWad,
                totalLiquidity: originalLiquidity,
                params: slot
            }) - int256(0);

        console2.log("remainder");
        console2.logInt(difference);

        // Valid should check that the trading function growth is >= expected fee growth.
        valid = difference >= int256(ZERO);
    }

    /// @dev Compute total liquidity given x reserves.
    /// @return L_x(x, S) = x * WAD / (WAD - Gaussian.cdf[d1(S, K, sigma, tau)])
    function lx(
        uint256 reserveXWad,
        uint256 priceWad,
        Parameters memory params
    ) public pure returns (uint256) {
        // Computes d1 = (ln(price / K) + tau * sigma^2 / 2)) / (sigma * sqrt(tau))
        int256 d1 = computeD1({ priceWad: priceWad, params: params });
        // Computes the cumulative distribution function of d1.
        int256 cdf = Gaussian.cdf(d1);
        // Cumulative distribution function's domain is [0, 1], so it can be casted to an unsigned integer safely.
        uint256 unsignedCdf = toUint(cdf);
        // L = x * WAD / (WAD - cdf(d1))
        require(unsignedCdf < WAD, "lx: denominator is zero");
        return reserveXWad.divWadDown(WAD - unsignedCdf);
    }

    /// @dev Computes total liquidity given y reserves.
    /// @return L_y(y, S) = y * WAD / (K * Gaussian.cdf[d2(S, K, sigma, tau)])
    function ly(
        uint256 reserveYWad,
        uint256 priceWad,
        Parameters memory params
    ) public pure returns (uint256) {
        int256 d2 = computeD2({ priceWad: priceWad, params: params });
        int256 cdf = Gaussian.cdf(d2);
        uint256 unsignedCdf = toUint(cdf);
        return reserveYWad.divWadDown(
            params.strikePriceWad.mulWadDown(unsignedCdf)
        );
    }

    /// @dev Computes reserves y given L(x, S).
    /// @return y(x, s) = K * L_x(x, S) * Gaussian.cdf[d2(S, K, sigma, tau)]
    function yl(
        uint256 totalLiquidity,
        uint256 priceWad,
        Parameters memory params
    ) public pure returns (uint256) {
        int256 d2 = computeD2({ priceWad: priceWad, params: params });
        int256 cdf = Gaussian.cdf(d2);
        uint256 unsignedCdf = toUint(cdf);
        return
            params.strikePriceWad.mulWadUp(totalLiquidity).mulWadUp(unsignedCdf);
    }

    /// @dev Computes reserves x given L(y, S).
    /// @return x(y, s) = L_y(y, S) * (WAD - Gaussian.cdf[d1(S, K, sigma, tau)])
    function xl(
        uint256 totalLiquidity,
        uint256 priceWad,
        Parameters memory params
    ) public pure returns (uint256) {
        int256 d1 = computeD1({ priceWad: priceWad, params: params });
        int256 cdf = Gaussian.cdf(d1);
        uint256 unsignedCdf = toUint(cdf);
        return totalLiquidity.mulWadUp(WAD - unsignedCdf);
    }

    function computeHalfSigmaSquared(uint256 sigmaPercentWad)
        public
        pure
        returns (uint256)
    {
        int256 sigmaSquaredWad = int256(sigmaPercentWad).powWad(TWO_WAD);
        return HALF_WAD.mulWadDown(uint256(sigmaSquaredWad));
    }

    /// @param priceWad The price of X in Y, in WAD units.
    /// @param params Parameters of the Log Normal distribution.
    /// @return d1 (ln(price / K) + tau * sigma^2 / 2)) / (sigma * sqrt(tau))
    function computeD1(
        uint256 priceWad,
        Parameters memory params
    ) public pure returns (int256 d1) {
        // sigma * sqrt(tau)
        uint256 sigmaSqrtTauWad = computeSigmaSqrtTau({
            sigmaPercentWad: params.sigmaPercentWad,
            tauYearsWad: params.tauYearsWad
        });
        // sigma^2 / 2
        uint256 halfSigmaSquaredWad =
            computeHalfSigmaSquared({ sigmaPercentWad: params.sigmaPercentWad });
        // ln(price / K), round UP because ln(1) = 0, but ln(0) = undefined.
        int256 logPriceOverStrikeWad = FixedPointMathLib.lnWad(
            int256(priceWad.divWadUp(params.strikePriceWad))
        );
        // Round up because the division is truncation in the lnWad function.
        logPriceOverStrikeWad++;
        // (ln(price / K) + tau * sigma^2 * tau / 2))
        int256 numerator = logPriceOverStrikeWad
            + int256(halfSigmaSquaredWad.mulWadDown(params.tauYearsWad));
        // sigma * sqrt(tau)
        int256 denominator = int256(sigmaSqrtTauWad);
        // (ln(price / K) + tau * sigma^2 / 2)) / (sigma * sqrt(tau))
        d1 = mulidivUp(numerator, int256(WAD), denominator);
    }

    /// @param priceWad The price of X in Y, in WAD units.
    /// @param params Parameters of the Log Normal distribution.
    /// @return d2 = d1 - sigma * sqrt(tau), alternatively d2 = (ln(S/K) - tau * sigma^2 / 2) / (sigma * sqrt(tau))
    function computeD2(
        uint256 priceWad,
        Parameters memory params
    ) public pure returns (int256 d2) {
        d2 = computeD1(priceWad, params)
            - int256(
                computeSigmaSqrtTau({
                    sigmaPercentWad: params.sigmaPercentWad,
                    tauYearsWad: params.tauYearsWad
                })
            );
    }

    /// @dev x * y / 1E18
    function mulWadDownInt(int256 x, int256 y) public pure returns (int256 z) {
        z = mulidiv(x, y, 1e18);
    }

    function mulidivUp(
        int256 x,
        int256 y,
        int256 denominator
    ) public pure returns (int256 z) {
        z = mulidiv(x, y, denominator);
        if ((x * y) % denominator != 0) {
            require(z < type(int256).max, "mulidivUp overflow");
            z += 1;
        }
    }

    /// @dev From Solmate, but not in assembly
    function mulidiv(
        int256 x,
        int256 y,
        int256 denominator
    ) public pure returns (int256 z) {
        unchecked {
            z = x * y;
            require(
                denominator != 0 && (x == 0 || z / x == y), "muldiv invalid"
            );
            z = z / denominator;
        }
    }

    function toUint(int256 x) public pure returns (uint256) {
        unchecked {
            require(x >= 0, "toUint: negative");
            return uint256(x);
        }
    }
}

/// @title DFMM
/// @notice Dynamic Function Market Maker
contract DFMM {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    address public tokenX;
    address public tokenY;
    uint256 public reserveXWad;
    uint256 public reserveYWad;
    uint256 public totalLiquidity;
    mapping(address account => uint256 balance) public balanceOf;

    constructor(address tokenX_, address tokenY_) {
        tokenX = tokenX_;
        tokenY = tokenY_;
    }

    event Swap(
        address indexed swapper,
        address source,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 amountLiquidity
    );

    bool public inited;

    modifier initialized() {
        require(inited, "not initialized");
        _;
    }

    uint256 public locked = 1;

    modifier lock() {
        require(locked == 1, "locked");
        locked = 0;
        _;
        locked = 1;
    }

    error Invalid(bool negative, uint256 difference);

    function magicConstant(address source) public view returns (int256) {
        bytes memory data = abi.encode(reserveXWad, reserveYWad, totalLiquidity);
        return LogNormal(source).magicConstant(data);
    }

    /// @param source The address of the source strategy contract.
    /// @param data The data to be passed to the source strategy contract for pool initialization & validation.
    function init(
        address source,
        bytes calldata data
    ) public lock returns (uint256, uint256, uint256) {
        (
            bool valid,
            int256 difference,
            uint256 XXXXXXX,
            uint256 YYYYYY,
            uint256 LLLLLL
        ) = Source(source).init(data);
        if (!valid) revert Invalid(difference < 0, abs(difference));
        inited = true;
        reserveXWad = XXXXXXX;
        reserveYWad = YYYYYY;
        totalLiquidity = LLLLLL;
        balanceOf[msg.sender] = LLLLLL;
        ERC20(tokenX).transferFrom(msg.sender, address(this), XXXXXXX);
        ERC20(tokenY).transferFrom(msg.sender, address(this), YYYYYY);
        return (XXXXXXX, YYYYYY, LLLLLL);
    }

    /// @param source The address of the source strategy contract.
    /// @param data The data to be passed to the source strategy contract for swap validation.
    function swap(
        address source,
        bytes calldata data
    ) public lock initialized {
        (
            bool valid,
            int256 difference,
            uint256 XXXXXXX,
            uint256 YYYYYY,
            uint256 LLLLLL
        ) = Source(source).validate(data);
        if (!valid) revert Invalid(difference < 0, abs(difference));

        uint256 originalLiquidity = totalLiquidity;
        require(LLLLLL >= originalLiquidity, "invalid liquidity");
        uint256 amountLiquidity = LLLLLL - originalLiquidity;
        totalLiquidity += amountLiquidity;

        {
            // Avoids stack too deep.
            (
                address inputToken,
                address outputToken,
                uint256 inputAmount,
                uint256 outputAmount
            ) = _settle({
                adjustedReserveXWad: XXXXXXX,
                adjustedReserveYWad: YYYYYY
            });

            address swapper = msg.sender;
            address strategy = source;
            emit Swap(
                swapper,
                strategy,
                inputToken,
                outputToken,
                inputAmount,
                outputAmount,
                amountLiquidity
            );
        }
    }

    function _settle(
        uint256 adjustedReserveXWad,
        uint256 adjustedReserveYWad
    )
        internal
        returns (
            address inputToken,
            address outputToken,
            uint256 inputAmount,
            uint256 outputAmount
        )
    {
        (uint256 originalReserveXWad, uint256 originalReserveYWad) =
            (reserveXWad, reserveYWad);

        if (adjustedReserveXWad > originalReserveXWad) {
            inputToken = tokenX;
            outputToken = tokenY;
            inputAmount = adjustedReserveXWad - originalReserveXWad;
            require(
                originalReserveYWad > adjustedReserveYWad,
                "invalid swap: inputs x and y"
            );
            outputAmount = originalReserveYWad - adjustedReserveYWad;
        } else {
            inputToken = tokenY;
            outputToken = tokenX;
            inputAmount = adjustedReserveYWad - originalReserveYWad;
            require(
                originalReserveXWad > adjustedReserveXWad,
                "invalid swap: inputs x and y"
            );
            outputAmount = originalReserveXWad - adjustedReserveXWad;
        }

        uint256 inputBalance = ERC20(inputToken).balanceOf(address(this));
        uint256 outputBalance = ERC20(outputToken).balanceOf(address(this));
        ERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);
        ERC20(outputToken).transfer(msg.sender, outputAmount);
        require(
            ERC20(inputToken).balanceOf(address(this))
                >= inputBalance + inputAmount,
            "invalid swap: input token transfer"
        );
        require(
            ERC20(outputToken).balanceOf(address(this))
                >= outputBalance - outputAmount,
            "invalid swap: output token transfer"
        );
    }

    function getReservesAndLiquidity()
        public
        view
        returns (uint256, uint256, uint256)
    {
        return (reserveXWad, reserveYWad, totalLiquidity);
    }
}
