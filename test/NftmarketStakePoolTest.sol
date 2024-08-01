// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NftmarketStakePool.sol";

contract NftmarketStakePoolTest is Test {
    NftmarketStakePool public stakePool;
    address public nftMarket;
    address public alice;
    address public bob;

    function setUp() public {
        nftMarket = address(this);
        stakePool = new NftmarketStakePool(nftMarket);
        alice = address(0x1);
        bob = address(0x2);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(address(stakePool), 10 ether); // 给质押池合约一些 ETH
    }

    function testStake() public {
        vm.prank(alice);
        stakePool.stake{value: 1 ether}();

        (uint256 stakeAmount, uint256 rewardDebt) = stakePool.userToStakeInfo(
            alice
        );
        assertEq(stakeAmount, 1 ether, "Stake amount should be 1 ether");
        assertEq(rewardDebt, 0, "Initial reward debt should be 0");
        assertEq(
            stakePool.totalStakeAmount(),
            1 ether,
            "Total stake amount should be 1 ether"
        );
    }

    function testUnstake() public {
        vm.prank(alice);
        stakePool.stake{value: 1 ether}();

        vm.prank(alice);
        uint256 balanceBefore = alice.balance;
        stakePool.unstake();

        assertEq(
            alice.balance,
            balanceBefore + 1 ether,
            "Alice should receive 1 ether back"
        );
        assertEq(
            stakePool.totalStakeAmount(),
            0,
            "Total stake amount should be 0"
        );
    }

    function testClaimReward() public {
        vm.prank(alice);
        stakePool.stake{value: 1 ether}();

        // 模拟一些奖励
        vm.prank(nftMarket);
        (bool success, ) = address(stakePool).call{value: 0.1 ether}("");
        require(success, "Failed to send reward");

        vm.prank(alice);
        uint256 balanceBefore = alice.balance;
        stakePool.claimReward();

        assertGt(
            alice.balance,
            balanceBefore,
            "Alice should receive some reward"
        );
    }

    function testMultipleStakers() public {
        vm.prank(alice);
        stakePool.stake{value: 1 ether}();

        vm.prank(bob);
        stakePool.stake{value: 2 ether}();

        // 模拟一些奖励
        vm.prank(nftMarket);
        (bool success, ) = address(stakePool).call{value: 0.3 ether}("");
        require(success, "Failed to send reward");

        vm.prank(alice);
        uint256 aliceBalanceBefore = alice.balance;
        stakePool.claimReward();

        vm.prank(bob);
        uint256 bobBalanceBefore = bob.balance;
        stakePool.claimReward();

        assertGt(
            alice.balance,
            aliceBalanceBefore,
            "Alice should receive some reward"
        );
        assertGt(
            bob.balance,
            bobBalanceBefore,
            "Bob should receive some reward"
        );
        assertGt(
            bob.balance - bobBalanceBefore,
            alice.balance - aliceBalanceBefore,
            "Bob should receive more reward than Alice"
        );
    }

    function testComplexStakingScenario() public {
        // 初始质押
        vm.prank(alice);
        stakePool.stake{value: 1 ether}();

        vm.prank(bob);
        stakePool.stake{value: 2 ether}();

        // 第一次奖励
        vm.prank(nftMarket);
        (bool success, ) = address(stakePool).call{value: 0.3 ether}("");
        require(success, "Failed to send first reward");

        // Charlie加入质押
        address charlie = address(0x3);
        vm.deal(charlie, 100 ether);
        vm.prank(charlie);
        stakePool.stake{value: 3 ether}();

        // 第二次奖励
        vm.prank(nftMarket);
        (success, ) = address(stakePool).call{value: 0.6 ether}("");
        require(success, "Failed to send second reward");

        // Bob部分取消质押
        vm.prank(bob);
        uint256 bobBalanceBefore = bob.balance;
        stakePool.unstake();

        // 第三次奖励
        vm.prank(nftMarket);
        (success, ) = address(stakePool).call{value: 0.4 ether}("");
        require(success, "Failed to send third reward");

        // 所有人领取奖励
        vm.prank(alice);
        uint256 aliceBalanceBefore = alice.balance;
        stakePool.claimReward();

        vm.prank(charlie);
        uint256 charlieBalanceBefore = charlie.balance;
        stakePool.claimReward();

        // 计算实际奖励
        uint256 aliceReward = alice.balance - aliceBalanceBefore;
        uint256 bobReward = bob.balance - bobBalanceBefore;
        uint256 charlieReward = charlie.balance - charlieBalanceBefore;

        // 打印奖励
        console.log("Alice's reward:", aliceReward / 1E16);
        console.log("Bob's reward:", bobReward / 1E16);
        console.log("Charlie's reward:", charlieReward / 1E16);

        // 验证
        assertGt(aliceReward, 0, "Alice should receive some reward");
        assertGt(bobReward, 0, "Bob should receive some reward");
        assertGt(charlieReward, 0, "Charlie should receive some reward");

        // 验证奖励分配的正确性
        assertGt(
            bobReward,
            aliceReward,
            "Bob should receive more reward than Alice"
        );
        assertGt(
            charlieReward,
            aliceReward,
            "Charlie should receive more reward than Alice"
        );
    }

    function testComplexStake() public {
        // 初始质押
        vm.prank(alice);
        stakePool.stake{value: 5 ether}();

        vm.prank(bob);
        stakePool.stake{value: 5 ether}();

        //
        vm.prank(nftMarket);
        address(stakePool).call{value: 10 ether}("");

        // charlie stake
        address charlie = address(0x3);
        vm.deal(charlie, 100 ether);
        vm.prank(charlie);
        stakePool.stake{value: 5 ether}();
        

        // charlie balance
        uint charlieBalanceBefore = charlie.balance;
        
        // chalie claim reward
            vm.prank(nftMarket);
        address(stakePool).call{value: 30 ether}("");
        vm.prank(charlie);
        stakePool.claimReward();
        console.log("charlie balance", charlie.balance - charlieBalanceBefore);



        


        uint aliceBalanceBefore = alice.balance;
        uint bobBalanceBefore = bob.balance;
        // collect reward
        vm.prank(alice);
        stakePool.claimReward();

        vm.prank(bob);
        stakePool.claimReward();
        // check reward
        console.log("alice balance", alice.balance - aliceBalanceBefore);
        console.log("bob balance", bob.balance - bobBalanceBefore);
    }

    receive() external payable {}
}
