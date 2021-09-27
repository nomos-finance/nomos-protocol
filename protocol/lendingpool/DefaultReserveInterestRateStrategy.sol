// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {IReserveInterestRateStrategy} from '../../interfaces/IReserveInterestRateStrategy.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {ILendingPoolAddressesProvider} from '../../interfaces/ILendingPoolAddressesProvider.sol';
import {ILendingRateOracle} from '../../interfaces/ILendingRateOracle.sol';
import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';

/**
 * @title DefaultReserveInterestRateStrategy contract
 * @notice Implements the calculation of the interest rates depending on the reserve state
 * @dev The model of interest rate is based on 3 slopes
 * - An instance of this same contract, can't be used across different markets, due to the caching
 *   of the LendingPoolAddressesProvider
 * @author Nomos
 **/
contract DefaultReserveInterestRateStrategy is IReserveInterestRateStrategy {
  using WadRayMath for uint256;
  using SafeMath for uint256;
  using PercentageMath for uint256;

  /**
   * @dev this constant represents the utilization rate at which the pool aims to the first stage borrow rates.
   * Expressed in ray
   **/
  uint256 public immutable FIRST_UTILIZATION_RATE;

  /**
   * @dev this constant represents the utilization rate at which the pool aims to the second stage borrow rates.
   * Expressed in ray
   **/
  uint256 public immutable SECOND_UTILIZATION_RATE;


  /**
   * @dev This constant represents the excess utilization rate above the second stage. It's always equal to
   * second stage - first stage utilization rate. Added as a constant here for gas optimizations.
   * Expressed in ray
   **/

  uint256 public immutable EXCESS_UTILIZATION_RATE1;

  /**
   * @dev This constant represents the excess utilization rate above the second stage. It's always equal to
   * 1-second stage utilization rate. Added as a constant here for gas optimizations.
   * Expressed in ray
   **/

  uint256 public immutable EXCESS_UTILIZATION_RATE2;

  ILendingPoolAddressesProvider public immutable addressesProvider;

  // Base variable borrow rate when Utilization rate = 0. Expressed in ray
  uint256 internal immutable _baseVariableBorrowRate;

  // Slope of the variable interest curve when utilization rate > 0 and <= FIRST_UTILIZATION_RATE. Expressed in ray
  uint256 internal immutable _variableRateSlope1;

  // Slope of the variable interest curve when utilization rate > FIRST_UTILIZATION_RATE and <= SECOND_UTILIZATION_RATE. Expressed in ray
  uint256 internal immutable _variableRateSlope2;

  // Slope of the variable interest curve when utilization rate > SECOND_UTILIZATION_RATE. Expressed in ray
  uint256 internal immutable _variableRateSlope3;

  // Slope of the stable interest curve when utilization rate > 0 and <= FIRST_UTILIZATION_RATE. Expressed in ray
  uint256 internal immutable _stableRateSlope1;

  // Slope of the stable interest curve when utilization rate > FIRST_UTILIZATION_RATE and <= SECOND_UTILIZATION_RATE. Expressed in ray
  uint256 internal immutable _stableRateSlope2;

  // Slope of the stable interest curve when utilization rate > SECOND_UTILIZATION_RATE. Expressed in ray
  uint256 internal immutable _stableRateSlope3;

  constructor(
    ILendingPoolAddressesProvider provider,
    uint256 firstUtilizationRate,
    uint256 secondUtilizationRate,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2,
    uint256 variableRateSlope3,
    uint256 stableRateSlope1,
    uint256 stableRateSlope2,
    uint256 stableRateSlope3
  ) public {
    FIRST_UTILIZATION_RATE = firstUtilizationRate;
    SECOND_UTILIZATION_RATE = secondUtilizationRate;
    EXCESS_UTILIZATION_RATE1 = secondUtilizationRate-firstUtilizationRate;
    EXCESS_UTILIZATION_RATE2 = WadRayMath.ray().sub(secondUtilizationRate);
    addressesProvider = provider;
    _baseVariableBorrowRate = baseVariableBorrowRate;
    _variableRateSlope1 = variableRateSlope1;
    _variableRateSlope2 = variableRateSlope2;
    _variableRateSlope3 = variableRateSlope3;
    _stableRateSlope1 = stableRateSlope1;
    _stableRateSlope2 = stableRateSlope2;
    _stableRateSlope3 = stableRateSlope3;
  }

  function variableRateSlope1() external view returns (uint256) {
    return _variableRateSlope1;
  }

  function variableRateSlope2() external view returns (uint256) {
    return _variableRateSlope2;
  }

  function variableRateSlope3() external view returns (uint256) {
    return _variableRateSlope3;
  }

  function stableRateSlope1() external view returns (uint256) {
    return _stableRateSlope1;
  }

  function stableRateSlope2() external view returns (uint256) {
    return _stableRateSlope2;
  }

  function stableRateSlope3() external view returns (uint256) {
    return _stableRateSlope3;
  }

  function baseVariableBorrowRate() external view override returns (uint256) {
    return _baseVariableBorrowRate;
  }

  function getMaxVariableBorrowRate() external view override returns (uint256) {
    return _baseVariableBorrowRate.add(_variableRateSlope1).add(_variableRateSlope2).add(_variableRateSlope3);
  }

  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param reserve The address of the reserve
   * @param aToken The address of the associated aToken contract
   * @param liquidityAdded The liquidity added during the operation
   * @param liquidityTaken The liquidity taken during the operation
   * @param totalStableDebt The total borrowed from the reserve a stable rate
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param averageStableBorrowRate The weighted average of all the stable rate loans
   * @param reserveFactor The reserve portion of the interest that goes to the treasury of the market
   * @return The liquidity rate, the stable borrow rate and the variable borrow rate
   **/
  function calculateInterestRates(
    address reserve,
    address aToken,
    uint256 liquidityAdded,
    uint256 liquidityTaken,
    uint256 totalStableDebt,
    uint256 totalVariableDebt,
    uint256 averageStableBorrowRate,
    uint256 reserveFactor
  )
    external
    view
    override
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 availableLiquidity = IERC20(reserve).balanceOf(aToken);
    //avoid stack too deep
    availableLiquidity = availableLiquidity.add(liquidityAdded).sub(liquidityTaken);

    return
      calculateInterestRates(
        reserve,
        availableLiquidity,
        totalStableDebt,
        totalVariableDebt,
        averageStableBorrowRate,
        reserveFactor
      );
  }

  struct CalcInterestRatesLocalVars {
    uint256 totalDebt;
    uint256 currentVariableBorrowRate;
    uint256 currentStableBorrowRate;
    uint256 currentLiquidityRate;
    uint256 utilizationRate;
  }

  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations.
   * NOTE This function is kept for compatibility with the previous DefaultInterestRateStrategy interface.
   * New protocol implementation uses the new calculateInterestRates() interface
   * @param reserve The address of the reserve
   * @param availableLiquidity The liquidity available in the corresponding aToken
   * @param totalStableDebt The total borrowed from the reserve a stable rate
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param averageStableBorrowRate The weighted average of all the stable rate loans
   * @param reserveFactor The reserve portion of the interest that goes to the treasury of the market
   * @return The liquidity rate, the stable borrow rate and the variable borrow rate
   **/
  function calculateInterestRates(
    address reserve,
    uint256 availableLiquidity,
    uint256 totalStableDebt,
    uint256 totalVariableDebt,
    uint256 averageStableBorrowRate,
    uint256 reserveFactor
  )
    public
    view
    override
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    CalcInterestRatesLocalVars memory vars;

    vars.totalDebt = totalStableDebt.add(totalVariableDebt);
    vars.currentVariableBorrowRate = 0;
    vars.currentStableBorrowRate = 0;
    vars.currentLiquidityRate = 0;

    vars.utilizationRate = vars.totalDebt == 0
      ? 0
      : vars.totalDebt.rayDiv(availableLiquidity.add(vars.totalDebt));

    vars.currentStableBorrowRate = ILendingRateOracle(addressesProvider.getLendingRateOracle())
      .getMarketBorrowRate(reserve);

    if (vars.utilizationRate > SECOND_UTILIZATION_RATE) {
      uint256 excessUtilizationRateRatio =
        vars.utilizationRate.sub(SECOND_UTILIZATION_RATE).rayDiv(EXCESS_UTILIZATION_RATE2);

      vars.currentStableBorrowRate = vars.currentStableBorrowRate.add(_stableRateSlope1).add(_stableRateSlope2).add(
        _stableRateSlope3.rayMul(excessUtilizationRateRatio)
      );

      vars.currentVariableBorrowRate = _baseVariableBorrowRate.add(_variableRateSlope1).add(_variableRateSlope2).add(
        _variableRateSlope3.rayMul(excessUtilizationRateRatio)
      );
    } else if (vars.utilizationRate > FIRST_UTILIZATION_RATE && vars.utilizationRate <= SECOND_UTILIZATION_RATE) {
      uint256 excessUtilizationRateRatio =
        vars.utilizationRate.sub(FIRST_UTILIZATION_RATE).rayDiv(EXCESS_UTILIZATION_RATE1);

      vars.currentStableBorrowRate = vars.currentStableBorrowRate.add(_stableRateSlope1).add(
        _stableRateSlope2.rayMul(excessUtilizationRateRatio)
      );

      vars.currentVariableBorrowRate = _baseVariableBorrowRate.add(_variableRateSlope1).add(
        _variableRateSlope2.rayMul(excessUtilizationRateRatio)
      );
    } else {
      vars.currentStableBorrowRate = vars.currentStableBorrowRate.add(
        _stableRateSlope1.rayMul(vars.utilizationRate.rayDiv(FIRST_UTILIZATION_RATE))
      );
      vars.currentVariableBorrowRate = _baseVariableBorrowRate.add(
        vars.utilizationRate.rayMul(_variableRateSlope1).rayDiv(FIRST_UTILIZATION_RATE)
      );
    }

    vars.currentLiquidityRate = _getOverallBorrowRate(
      totalStableDebt,
      totalVariableDebt,
      vars
        .currentVariableBorrowRate,
      averageStableBorrowRate
    )
      .rayMul(vars.utilizationRate)
      .percentMul(PercentageMath.PERCENTAGE_FACTOR.sub(reserveFactor));

    return (
      vars.currentLiquidityRate,
      vars.currentStableBorrowRate,
      vars.currentVariableBorrowRate
    );
  }

  /**
   * @dev Calculates the overall borrow rate as the weighted average between the total variable debt and total stable debt
   * @param totalStableDebt The total borrowed from the reserve a stable rate
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param currentVariableBorrowRate The current variable borrow rate of the reserve
   * @param currentAverageStableBorrowRate The current weighted average of all the stable rate loans
   * @return The weighted averaged borrow rate
   **/
  function _getOverallBorrowRate(
    uint256 totalStableDebt,
    uint256 totalVariableDebt,
    uint256 currentVariableBorrowRate,
    uint256 currentAverageStableBorrowRate
  ) internal pure returns (uint256) {
    uint256 totalDebt = totalStableDebt.add(totalVariableDebt);

    if (totalDebt == 0) return 0;

    uint256 weightedVariableRate = totalVariableDebt.wadToRay().rayMul(currentVariableBorrowRate);

    uint256 weightedStableRate = totalStableDebt.wadToRay().rayMul(currentAverageStableBorrowRate);

    uint256 overallBorrowRate =
      weightedVariableRate.add(weightedStableRate).rayDiv(totalDebt.wadToRay());

    return overallBorrowRate;
  }
}
