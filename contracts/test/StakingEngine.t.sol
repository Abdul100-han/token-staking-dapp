// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingEngine} from "../src/StakingEngine.sol";

contract StakingEngineTest is Test {
    StakingToken public stakingToken;
    RewardToken public rewardToken;
    StakingEngine public stakingEngine;

    address public alice;
    address public bob;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant STAKE_AMOUNT = 100 ether;
    uint256 public constant WARP_SECONDS = 10;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    function setUp() public {
        stakingToken = new StakingToken();
        rewardToken = new RewardToken();
        stakingEngine = new StakingEngine(address(stakingToken), address(rewardToken));

        rewardToken.transferOwnership(address(stakingEngine));

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        stakingToken.mint(alice, INITIAL_BALANCE);
        stakingToken.mint(bob, INITIAL_BALANCE);

        vm.prank(alice);
        stakingToken.approve(address(stakingEngine), type(uint256).max);

        vm.prank(bob);
        stakingToken.approve(address(stakingEngine), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(address(stakingEngine.stakingToken()), address(stakingToken));
        assertEq(address(stakingEngine.rewardToken()), address(rewardToken));
        assertEq(rewardToken.owner(), address(stakingEngine));

        assertEq(stakingEngine.totalSupply(), 0);
        assertEq(stakingEngine.balances(alice), 0);
        assertEq(stakingEngine.balances(bob), 0);
        assertEq(stakingEngine.rewardRate(), 100);
        assertEq(stakingEngine.rewardPerTokenStored(), 0);

        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(stakingToken.balanceOf(bob), INITIAL_BALANCE);
        assertEq(rewardToken.balanceOf(alice), 0);
        assertEq(rewardToken.balanceOf(bob), 0);
        assertEq(rewardToken.totalSupply(), 0);
    }

    function test_StakeTokens() public {
        vm.expectEmit(true, false, false, true, address(stakingEngine));
        emit Staked(alice, STAKE_AMOUNT);

        vm.prank(alice);
        stakingEngine.stake(STAKE_AMOUNT);

        assertEq(stakingEngine.totalSupply(), STAKE_AMOUNT);
        assertEq(stakingEngine.balances(alice), STAKE_AMOUNT);
        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE - STAKE_AMOUNT);
        assertEq(stakingToken.balanceOf(address(stakingEngine)), STAKE_AMOUNT);
    }

    function test_EarnRewardsOverTime() public {
        vm.prank(alice);
        stakingEngine.stake(STAKE_AMOUNT);

        vm.warp(block.timestamp + WARP_SECONDS);

        assertEq(stakingEngine.earned(alice), WARP_SECONDS * stakingEngine.rewardRate());
    }

    function test_ClaimRewards() public {
        vm.prank(alice);
        stakingEngine.stake(STAKE_AMOUNT);

        vm.warp(block.timestamp + WARP_SECONDS);

        uint256 expectedReward = WARP_SECONDS * stakingEngine.rewardRate();
        uint256 aliceRewardBefore = rewardToken.balanceOf(alice);

        vm.expectEmit(true, false, false, true, address(stakingEngine));
        emit RewardClaimed(alice, expectedReward);

        vm.prank(alice);
        stakingEngine.claimReward();

        assertEq(rewardToken.balanceOf(alice), aliceRewardBefore + expectedReward);
        assertEq(stakingEngine.earned(alice), 0);
        assertEq(stakingEngine.rewards(alice), 0);
    }

    function test_WithdrawAndExit() public {
        uint256 partialWithdraw = 40 ether;

        vm.prank(alice);
        stakingEngine.stake(STAKE_AMOUNT);

        vm.expectEmit(true, false, false, true, address(stakingEngine));
        emit Withdrawn(alice, partialWithdraw);

        vm.prank(alice);
        stakingEngine.withdraw(partialWithdraw);

        assertEq(stakingEngine.balances(alice), STAKE_AMOUNT - partialWithdraw);
        assertEq(stakingEngine.totalSupply(), STAKE_AMOUNT - partialWithdraw);
        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE - STAKE_AMOUNT + partialWithdraw);

        vm.warp(block.timestamp + WARP_SECONDS);

        uint256 remainingStake = stakingEngine.balances(alice);
        uint256 pendingRewards = stakingEngine.earned(alice);
        uint256 aliceStkBeforeExit = stakingToken.balanceOf(alice);
        uint256 aliceRwdBeforeExit = rewardToken.balanceOf(alice);

        vm.prank(alice);
        stakingEngine.exit();

        assertEq(stakingEngine.balances(alice), 0);
        assertEq(stakingEngine.totalSupply(), 0);
        assertEq(stakingEngine.earned(alice), 0);
        assertEq(stakingToken.balanceOf(alice), aliceStkBeforeExit + remainingStake);
        assertEq(rewardToken.balanceOf(alice), aliceRwdBeforeExit + pendingRewards);
    }

    function test_RevertIf_StakeZeroTokens() public {
        vm.prank(alice);
        vm.expectRevert("Cannot stake 0");
        stakingEngine.stake(0);
    }

    function test_RevertIf_WithdrawMoreThanStaked() public {
        vm.prank(alice);
        stakingEngine.stake(STAKE_AMOUNT);

        vm.prank(alice);
        vm.expectRevert("Insufficient staked balance");
        stakingEngine.withdraw(STAKE_AMOUNT + 1);
    }

    function testFuzz_StakeAndWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 ether);

        stakingToken.mint(alice, amount);

        uint256 initialBalance = stakingToken.balanceOf(alice);

        vm.prank(alice);
        stakingToken.approve(address(stakingEngine), amount);

        vm.prank(alice);
        stakingEngine.stake(amount);

        vm.warp(block.timestamp + WARP_SECONDS);

        vm.prank(alice);
        stakingEngine.withdraw(amount);

        assertEq(stakingEngine.balances(alice), 0);
        assertEq(stakingToken.balanceOf(alice), initialBalance);
    }
}
