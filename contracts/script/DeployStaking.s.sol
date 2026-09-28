// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingEngine} from "../src/StakingEngine.sol";

contract StakingBundle {
    StakingToken public immutable stakingToken;
    RewardToken public immutable rewardToken;
    StakingEngine public immutable stakingEngine;

    constructor() {
        StakingToken deployedStakingToken = new StakingToken();
        RewardToken deployedRewardToken = new RewardToken();
        StakingEngine deployedStakingEngine =
            new StakingEngine(address(deployedStakingToken), address(deployedRewardToken));

        deployedRewardToken.transferOwnership(address(deployedStakingEngine));
        deployedStakingToken.transferOwnership(msg.sender);
        deployedStakingEngine.transferOwnership(msg.sender);

        stakingToken = deployedStakingToken;
        rewardToken = deployedRewardToken;
        stakingEngine = deployedStakingEngine;
    }
}

contract DeployStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = _loadPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        StakingBundle bundle = new StakingBundle();

        vm.stopBroadcast();

        console.log("StakingToken deployed at:", address(bundle.stakingToken()));
        console.log("RewardToken deployed at:", address(bundle.rewardToken()));
        console.log("StakingEngine deployed at:", address(bundle.stakingEngine()));
        console.log("RewardToken owner:", bundle.rewardToken().owner());
    }

    function _loadPrivateKey() internal view returns (uint256) {
        string memory rawKey = vm.envString("PRIVATE_KEY");
        bytes memory keyBytes = bytes(rawKey);

        if (
            keyBytes.length >= 2 && keyBytes[0] == "0"
                && (keyBytes[1] == "x" || keyBytes[1] == "X")
        ) {
            return vm.parseUint(rawKey);
        }

        return vm.parseUint(string.concat("0x", rawKey));
    }
}
