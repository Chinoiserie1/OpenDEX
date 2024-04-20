// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {OpenDexPair} from "../src/OpenDexPair.sol";
import {TestERC20} from '../src/testToken/TestERC20.sol';

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
    testETH.transfer(address(pair), 1.1 ether);
    pair.swap(1 ether, 0);
  }
}
