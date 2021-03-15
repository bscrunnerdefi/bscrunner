// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./OwnableToken.sol";


contract RunnerToken is OwnableToken {
  constructor() OwnableToken("Runner", "RUNNER") {}
}