// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OpenDexPair} from "./OpenDexPair.sol";

error IdenticalAddress();

contract OpenDexFactory {
  mapping(address => mapping(address => address)) public getPair;

  event PairCreated(address indexed token0, address indexed token1, address pair);

  function createPair(address tokenA, address tokenB) external returns (address pair) {
    require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
    require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
    bytes memory bytecode = type(OpenDexPair).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(token0, token1));
    assembly {
        pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
    OpenDexPair(pair).initPair(token0, token1);
    getPair[token0][token1] = pair;
    getPair[token1][token0] = pair; // populate mapping in the reverse direction
  }
}