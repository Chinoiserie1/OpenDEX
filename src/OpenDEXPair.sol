// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OpenDexERC20} from "./OpenDexERC20.sol";

import {Test, console2} from "forge-std/Test.sol";

uint256 constant MINIMUM_LIQUIDITY = 10**3;

error Reantrant();
error InvalidAmount();
error NoAmount();
error InsufficientLiquidity();
error VariableKNotMatch();

/**
 * @notice Simple ERC20 Decentralized Exchange by chixx.eth
 */
contract OpenDexPair is OpenDexERC20 {
  address public factory;
  address public token0;
  address public token1;

  uint256 private reserve0;
  uint256 private reserve1;
  uint256 private kVariable;

  uint256 private reantrant = 1;

  constructor(address _factory, address _token0, address _token1) {
    factory = _factory;
    token0 = _token0;
    token1 = _token1;
  }

    modifier reantrancyGuard {
    if (reantrant == 0) revert Reantrant();
    reantrant = 0;
    _;
    reantrant = 1;
  }

  function addLiquidity(uint256 amount0, uint256 amount1) external reantrancyGuard returns(uint256 liquidity) {
    uint256 _totalSupply = totalSupply;
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    if (_totalSupply == 0) {
      liquidity = amount0 + amount1 - MINIMUM_LIQUIDITY;
      _mint(address(0), MINIMUM_LIQUIDITY);
    } else {
      uint256 liquidityX = amount0 * _totalSupply / balance0;
      uint256 liquidityY = amount1 * _totalSupply / balance1;
      liquidity = (liquidityX + liquidityY) / 2;
    }

    IERC20(token0).transferFrom(msg.sender, address(this), amount0);
    IERC20(token1).transferFrom(msg.sender, address(this), amount1);

    _mint(msg.sender, liquidity);

    _syncReserve();

    kVariable = reserve0 * reserve1;
  }

  function removeLiquidity(uint256 lpTokenAmount) external reantrancyGuard returns(uint256 token0Out, uint256 token1Out) {
    uint256 _totalSupply = totalSupply;
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    token0Out = lpTokenAmount * balance0 / _totalSupply;
    token1Out = lpTokenAmount * balance1 / _totalSupply;

    _burn(msg.sender, lpTokenAmount);
    IERC20(token0).transfer(msg.sender, token0Out);
    IERC20(token1).transfer(msg.sender, token1Out);

    _syncReserve();

    kVariable = reserve0 * reserve1;
  }

  /**
   * @notice Swap function with a 0.3% base fees
   */
  function swap(uint256 amount0In, uint256 amount1In) external reantrancyGuard returns(uint256) {
    if (amount0In == 0 && amount1In == 0) revert NoAmount();
    if (amount0In > 0 && amount1In > 0) revert InvalidAmount();
    if (amount0In > reserve0 || amount1In > reserve1) revert InsufficientLiquidity();

    uint256 amountOut;
    if (amount0In > 0) {
      amountOut = reserve1 - (reserve0 * reserve1) / (reserve0 + amount0In * (10000 - 30) / 10000);
      IERC20(token0).transferFrom(msg.sender, address(this), amount0In);
      IERC20(token1).transfer(msg.sender, amountOut);
    } else {
      amountOut = reserve0 - (reserve0 * reserve1) / (reserve1 + amount1In * (10000 - 30) / 10000);
      IERC20(token1).transferFrom(msg.sender, address(this), amount1In);
      IERC20(token0).transfer(msg.sender, amountOut);
    }

    _syncReserve();

    if (kVariable > reserve0 * reserve1) revert VariableKNotMatch();

    return (amountOut);
  }

  function _syncReserve() internal {
    reserve0 = IERC20(token0).balanceOf(address(this));
    reserve1 = IERC20(token1).balanceOf(address(this));
  }
}
