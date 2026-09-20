// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingEngine} from "../src/StakingEngine.sol";

contract DeployStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        StakingToken stakingToken = new StakingToken();
        RewardToken rewardToken = new RewardToken();
        StakingEngine stakingEngine = new StakingEngine(address(stakingToken), address(rewardToken));

        rewardToken.transferOwnership(address(stakingEngine));

        vm.stopBroadcast();

        console.log("StakingToken deployed at:", address(stakingToken));
        console.log("RewardToken deployed at:", address(rewardToken));
        console.log("StakingEngine deployed at:", address(stakingEngine));
        console.log("RewardToken owner:", rewardToken.owner());
    }
}
