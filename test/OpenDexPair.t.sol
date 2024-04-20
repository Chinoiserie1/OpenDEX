// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {OpenDexPair} from "../src/OpenDexPair.sol";
import {TestERC20} from '../src/testToken/TestERC20.sol';

uint256 constant maxUint = uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
uint256 constant halfMaxUint = uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
uint256 constant bigUint = uint256(0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

contract CounterTest is Test {
  OpenDexPair public pair;
  TestERC20 public testETH;
  TestERC20 public testDAI;

  uint256 internal ownerPrivateKey;
  address internal owner;
  uint256 internal user1PrivateKey;
  address internal user1;
  uint256 internal user2PrivateKey;
  address internal user2;
  uint256 internal user3PrivateKey;
  address internal user3;
  uint256 internal signerPrivateKey;
  address internal signer;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    user2PrivateKey = 0xFE55E;
    user2 = vm.addr(user2PrivateKey);
    user3PrivateKey = 0xD1C;
    user3 = vm.addr(user3PrivateKey);
    signerPrivateKey = 0xF10;
    signer = vm.addr(signerPrivateKey);
    vm.startPrank(owner);

    testETH = new TestERC20();
    testDAI = new TestERC20();
    pair = new OpenDexPair(owner, address(testETH), address(testDAI));
  }

  function testAddLiquidity() public {
    testETH.approve(address(pair), 50000 ether);
    testDAI.approve(address(pair), 50000 ether);
    pair.addLiquidity(500 ether, 1000 ether);
    pair.addLiquidity(50 ether, 100 ether);
  }

  function testRemoveLiquidity() public {
    testETH.approve(address(pair), 50000 ether);
    testDAI.approve(address(pair), 50000 ether);
    uint256 liquidity = pair.addLiquidity(500 ether, 1000 ether);
    pair.removeLiquidity(liquidity);
  }

  function testSwap() public {
    testETH.approve(address(pair), 50000 ether);
    testDAI.approve(address(pair), 50000 ether);
    pair.addLiquidity(500 ether, 1000 ether);
    // testETH.transfer(address(pair), 1.1 ether);
    pair.swap(1 ether, 0);
  }

  function testAddLiquidityFuzzAmountIn0(uint256 amount0In) public {
    if (amount0In < 1 ether) return;
    uint256 amount1Liquidity = amount0In / 2;
    if (amount0In > bigUint) {
      amount1Liquidity = 2;
      return;
    }
    if (amount0In > halfMaxUint - 1) return;
    testETH.approve(address(pair), amount0In);
    testDAI.approve(address(pair), amount0In / 2);
    pair.addLiquidity(amount0In, amount1Liquidity);
  }
}
