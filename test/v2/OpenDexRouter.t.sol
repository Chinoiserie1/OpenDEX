// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import '../../src/v2/OpenDexRouter.sol';
import '../../src/v2/OpenDexFactory.sol';
import {TestERC20} from '../../src/testToken/TestERC20.sol';

contract TestOpenDexRouter is Test {
  OpenDexFactory public factory;
  OpenDexRouter public router;
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
  uint256 internal feeSetterPrivateKey;
  address internal feeSetter;
  uint256 internal feePrivateKey;
  address internal fee;

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
    feeSetterPrivateKey = 0xfee5e11e5;
    feeSetter = vm.addr(feeSetterPrivateKey);
    feePrivateKey = 0xfee;
    fee = vm.addr(feePrivateKey);
    
    vm.startPrank(owner);

    factory = new OpenDexFactory(feeSetter);
    router = new OpenDexRouter(address(factory));
    testETH = new TestERC20();
    testDAI = new TestERC20();
  }

  function test() public {
    address pair = factory.createPair(address(testETH), address(testDAI));
    router.addLiquidity(address(testETH), address(testDAI), 10 ether, 10 ether, 8 ether, 8 ether, owner, 1 days);
  }
}