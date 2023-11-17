// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solstat/Gaussian.sol";

uint256 constant ONE = 1e18;

uint256 constant HALF = 0.5e18;

uint256 constant TWO = 2e18;

function toWad(uint256 a) pure returns (uint256) {
    return a * ONE;
}

function fromWad(uint256 a) pure returns (uint256) {
    return a / ONE;
}

function computeLGivenX(
    uint256 x,
    uint256 S,
    uint256 K,
    uint256 sigma
) pure returns (uint256 L) {
    int256 lnSDivK =
        FixedPointMathLib.lnWad(int256(FixedPointMathLib.divWadUp(S, K)));
    uint256 halfSigmaPowTwo = FixedPointMathLib.mulWadUp(
        HALF, uint256(FixedPointMathLib.powWad(int256(sigma), int256(TWO)))
    );
    int256 cdf =
        Gaussian.cdf((lnSDivK + int256(halfSigmaPowTwo)) * 1e18 / int256(sigma));
    int256 denominator = int256(1e18) - cdf;
    L = FixedPointMathLib.divWadUp(x, uint256(denominator));
}

function computeLGivenY(
    uint256 y,
    uint256 S,
    uint256 K,
    uint256 sigma
) pure returns (uint256 L) {
    int256 lnSDivK =
        FixedPointMathLib.lnWad(int256(FixedPointMathLib.divWadUp(S, K)));
    uint256 halfSigmaPowTwo = FixedPointMathLib.mulWadUp(
        HALF, uint256(FixedPointMathLib.powWad(int256(sigma), int256(TWO)))
    );
    int256 cdf =
        Gaussian.cdf((lnSDivK - int256(halfSigmaPowTwo)) * 1e18 / int256(sigma));
    L = FixedPointMathLib.divWadUp(
        y, FixedPointMathLib.mulWadUp(K, uint256(cdf))
    );
}

function computeXGivenL(
    uint256 L,
    uint256 S,
    uint256 K,
    uint256 sigma
) pure returns (uint256 x) {
    int256 lnSDivK =
        FixedPointMathLib.lnWad(int256(FixedPointMathLib.divWadUp(S, K)));
    uint256 halfSigmaPowTwo = FixedPointMathLib.mulWadUp(
        HALF, uint256(FixedPointMathLib.powWad(int256(sigma), int256(TWO)))
    );
    int256 cdf =
        Gaussian.cdf((lnSDivK + int256(halfSigmaPowTwo)) * 1e18 / int256(sigma));
    x = FixedPointMathLib.mulWadUp(L, uint256(int256(ONE) - cdf));
}

function computeYGivenL(
    uint256 L,
    uint256 S,
    uint256 K,
    uint256 sigma
) pure returns (uint256 y) {
    int256 lnSDivK =
        FixedPointMathLib.lnWad(int256(FixedPointMathLib.divWadUp(S, K)));
    uint256 halfSigmaPowTwo = FixedPointMathLib.mulWadUp(
        HALF, uint256(FixedPointMathLib.powWad(int256(sigma), int256(TWO)))
    );
    int256 minus = lnSDivK - int256(halfSigmaPowTwo);
    int256 div = minus * 1e18 / int256(sigma);
    int256 cdf = Gaussian.cdf(div);
    y = FixedPointMathLib.mulWadUp(
        K, FixedPointMathLib.mulWadUp(L, uint256(cdf))
    );
}
// p = Ke^{\Phi^{-1}(1-R_1)}\sigma\sqrt{T - \frac{1}{2}\sigma^2 \tau}.
function computeSpotPrice(
    uint256 x,
    uint256 L,
    uint256 K,
    uint256 sigma,
    uint256 tau
) pure returns (uint256) {
    uint256 innerTerm = FixedPointMathLib.mulWadDown(
        uint256(FixedPointMathLib.powWad(int256(sigma), int256(TWO))), tau
    );

    uint256 halfSigmaPower2Tau = FixedPointMathLib.mulWadDown(
        HALF,
        innerTerm
    );

    uint256 sqrtTau = FixedPointMathLib.sqrt(tau) * 10 ** 9;

    uint256 sigmaSqrtTau = FixedPointMathLib.mulWadDown(
        sigma, sqrtTau
    );

    uint256 R1 = FixedPointMathLib.divWadDown(x, L);

    return FixedPointMathLib.mulWadUp(
        K,
        uint256(
            FixedPointMathLib.expWad(
                Gaussian.ppf(int256(ONE - R1)) * int256(sigmaSqrtTau) / int256(ONE) - int256(halfSigmaPower2Tau)
            )
        )
    );
}

// The formula for computing the change in y (deltaY) is as follows:
// deltaY = K(L + deltaL) * Phi(-sigma - Phi^-1((x + deltaX) / (L + deltaL))) - y 
// where Phi is the cumulative distribution function of the standard normal distribution,
// Phi^-1 is the inverse of the Phi function,
// sigma is the volatility,
// L is the liquidity,
// deltaL is the change in liquidity,
// K is the strike price,
// x is the reserve x,
// deltaX is the x amount in,
// y is the reserve y,
// deltaY is the y amount out.
function computeOutputYGivenX(
    uint256 x, //reserve x
    uint256 y, // reserve y
    uint256 deltaX, // x amount in
    uint256 L, // liquidity
    uint256 deltaL, // change in liquidity
    uint256 K, // strike price
    uint256 sigma // volatility
) pure returns (int256) {
    uint256 KL = FixedPointMathLib.mulWadDown(K, L + deltaL);

    int256 cdf = Gaussian.cdf(
        -int256(sigma)
            - Gaussian.ppf(
                int256(FixedPointMathLib.divWadDown(x + deltaX, L + deltaL))
            )
    );

    return int256(FixedPointMathLib.mulWadDown(KL, uint256(cdf))) - int256(y);
}

// The formula for computing the change in x (deltaX) is as follows:
// deltaX = (L + deltaL) * Phi(-sigma - Phi^-1((y + deltaY) / (K * (L + deltaL)))) - x 
// where Phi is the cumulative distribution function of the standard normal distribution,
// Phi^-1 is the inverse of the Phi function,
// sigma is the volatility,
// L is the liquidity,
// deltaL is the change in liquidity,
// K is the strike price,
// y is the reserve y,
// deltaY is the y amount in,
// x is the reserve x,
// deltaX is the x amount in.
function computeOutputXGivenY(
    uint256 x, //reserve x
    uint256 y, // reserve y
    uint256 deltaY, // y amount in
    uint256 L, // liquidity
    uint256 deltaL, // change in liquidity
    uint256 K, // strike price
    uint256 sigma // volatility
) pure returns (int256) {
    uint256 KL = FixedPointMathLib.mulWadDown(K, L + deltaL);

    int256 cdf = Gaussian.cdf(
        -int256(sigma)
            - Gaussian.ppf(
                int256(FixedPointMathLib.divWadDown(y + deltaY, KL))
            )
    );

    return int256(FixedPointMathLib.mulWadDown(L + deltaL, uint256(cdf))) - int256(x);
}

function computeInvariant(
    uint256 reserveX,
    uint256 liquidity,
    uint256 reserveY,
    uint256 strikePrice
) pure returns (int256) {
    return Gaussian.ppf(int256(reserveX / liquidity))
        + Gaussian.ppf(
            int256(reserveY / FixedPointMathLib.mulWadDown(liquidity, strikePrice))
        );
}
