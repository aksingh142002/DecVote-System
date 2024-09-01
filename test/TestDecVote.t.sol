// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployVotingSystem} from "../script/DeployDecVote.s.sol";
import {DecVotingSystem} from "../src/DecVote.sol";

contract TestVotingSystem is Test {

  address deployer;
  DecVotingSystem test_DecVote;

  function setUp() external {
    DeployVotingSystem deploy = new DeployVotingSystem();
    test_DecVote = deploy.run();
    deployer = msg.sender;
  }

  function test_Owner() public view {
    assertEq(test_DecVote.i_owner(), deployer);
  }
}