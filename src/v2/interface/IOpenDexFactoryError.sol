// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IOpenDexFactoryError {
  error IdenticalAddress();
  error AddressZero();
  error PairExist();
}