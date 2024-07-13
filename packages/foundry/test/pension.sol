// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "../contracts/pension.sol";
import {MintableSuperToken} from "./MintableSuperToken.sol";
import {
    BatchOperation,
    ISuperfluid
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperApp.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ERC1820RegistryCompiled} from
    "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { TestToken } from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import { SuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import {StorageLib, Storage} from "../contracts/storageLib.sol";


interface IMint {
    function initialize(address factory, string memory _name, string memory _symbol) external;
    function mint(address to, uint256 amount ) external;
}

struct Team {
    address leader;
    bool isWinning;
}

/** 

forge test --fork-url {rpc. Ex: https://base.llamarpc.com}

**/ 

contract PensionsTest is Test {
    using SuperTokenV1Library for ISuperToken;
    using StorageLib for Storage; 

    ISuperToken public cash;
    IMint public mintCash;
    ISuperToken public time;
    IMint public mintTime;
    Pensions public pensionContract;

    ISuperfluidPool cashPool;
    ISuperfluidPool timePool;

    address internal constant admin = address(0x476E2651BF97dE8a26e4A05a9c8e00A6EFa1390c); // has to be this address
    address internal constant alice = address(0x420);
    address internal constant bob = address(0x421);
    address internal constant charlie = address(0x422);
    address internal constant daniel = address(0x423);
    address internal constant emily = address(0x424);
    address internal constant flo = address(0x425);
    address internal constant gemma = address(0x426);
    address internal constant hillary = address(0x427);
    address[8] users = [alice, bob, charlie, daniel, emily, flo, gemma, hillary];
    string[8] names = ["alice", "bob", "charlie", "daniel", "emily", "flo", "gemma", "hillary"];
    // mapping of address to name
    function nameOf(address user) internal view returns (string memory){
        for(uint256 i = 0; i < users.length; i++) {
            if(users[i] == user) return names[i];
        }
        return "unknown";
    }

    function setUp() public {

        //create token
        address STFactory = 0x36be86dEe6BC726Ed0Cbd170ccD2F21760BC73D9; //celo
        //BASE 0xe20B9a38E0c96F61d1bA6b42a61512D56Fea1Eb3;

        vm.startPrank(admin);

        time = ISuperToken(address(new MintableSuperToken()));
        mintTime = IMint(address(time));
        
        console.log("deployed time: ", address(time));
        mintTime.initialize(STFactory, "time", "time");
        console.log("initialize time");

        cash = ISuperToken(address(new MintableSuperToken()));
        mintCash = IMint(address(cash));
        
        console.log("deployed cash: ", address(cash));
        mintCash.initialize(STFactory, "cash", "cash");
        console.log("initialize cash");

        pensionContract = new Pensions(cash, time);
        address pensionContractAddress = address(pensionContract);
        cashPool = pensionContract.cashPool();
        timePool = pensionContract.timePool();
        console.log("deployed pensionContract: ", pensionContractAddress);
        vm.startPrank(admin);
        mintTime.mint(pensionContractAddress, 1e12 ether);

        console.log("deployed pensionContract: ", address(pensionContract));
    }

    function dealTo(address to) internal {
        vm.startPrank(admin);
        mintCash.mint(to, 100 ether);
        vm.stopPrank();
    }

    function getWorkerHeadTimeFlowrate() internal view returns (int96) {
        return timePool.getMemberFlowRate(pensionContract.getWorkerHead());
    }

    function testStartStreamToGame() public {
        int96 flowRate = 1e12;
        //flowRate = int96(int256(bound(uint256(int256(flowRate)), 1, 1e14)));
        dealTo(alice);
        vm.startPrank(alice);
        
        uint256 balanceBefore = cash.balanceOf(alice);
        uint256 balanceAppBefore = cash.balanceOf(address(pensionContract));
        uint256 balanceTimeBefore = pensionContract.timeBalance(alice);
        cash.createFlow(address(pensionContract), flowRate);
        vm.stopPrank();
        uint256 timeshift = 100;
        vm.warp(block.timestamp + timeshift);
        uint256 balanceAfter = cash.balanceOf(alice);
        uint256 balanceAppAfter = cash.balanceOf(address(pensionContract));
        uint256 balanceTimeAfter = pensionContract.timeBalance(alice);

        console.log("balanceBefore: ", balanceBefore);
        console.log("balanceAfter: ", balanceAfter);
        console.log("balanceTimeBefore", balanceTimeBefore);
        console.log("balanceAppBefore: ", balanceAppBefore);
        console.log("balanceAppAfter: ", balanceAppAfter);
        console.log("balanceTimeAfter", balanceTimeAfter);
        assertEq(balanceAppAfter, uint256(int256(flowRate)) * timeshift);
        assertGt(balanceTimeAfter, 0);
    } 

    function testStartMultipleStreams() public {
        int96 aliceFlowRate = int96(2e6);
        int96 bobFlowRate = int96(1e6);
        int96 charlieFlowRate = int96(3e6);

        dealTo(alice);
        dealTo(bob);
        dealTo(charlie);

        console.log("pensionContract.workers.head(): ", pensionContract.getWorkerHead());
        console.log("timePool.getMemberFlowrate(alice): ", uint(int256(getWorkerHeadTimeFlowrate())));

        console.log("dealt the funds, now starting the streams");
        console.log("alice: ");
        vm.startPrank(alice);
        cash.createFlow(address(pensionContract), aliceFlowRate);
        vm.stopPrank();

        console.log("pensionContract.workers.head(): ", pensionContract.getWorkerHead());
        console.log("timePool.getMemberFlowrate(alice): ", uint(int256(getWorkerHeadTimeFlowrate())));

        console.log("bob: ");
        vm.startPrank(bob);
        cash.createFlow(address(pensionContract), bobFlowRate);
        vm.stopPrank();

        // need to adapt the total flowrate when a new user joins
        console.log("pensionContract.workers.head(): ", pensionContract.getWorkerHead());
        console.log("timePool.getMemberFlowrate(bob): ", uint(int256(getWorkerHeadTimeFlowrate())));
        
        console.log("charlie: ");
        vm.startPrank(charlie);
        cash.createFlow(address(pensionContract), charlieFlowRate);
        vm.stopPrank();

        console.log("pensionContract.workers.head(): ", pensionContract.getWorkerHead());
        console.log("timePool.getMemberFlowrate(charlie): ", uint(int256(getWorkerHeadTimeFlowrate())));
        


        vm.warp(block.timestamp + 100);
        console.log("alice time balance: ", pensionContract.timeBalance(alice));
        console.log("bob time balance: ", pensionContract.timeBalance(bob));
        console.log("charlie time balance: ", pensionContract.timeBalance(charlie));

        assertGt(pensionContract.timeBalance(alice), pensionContract.timeBalance(bob));
        assertGt(pensionContract.timeBalance(charlie), pensionContract.timeBalance(alice));
        assertGt(pensionContract.timeBalance(charlie), pensionContract.timeBalance(bob));
        // now we check that the order is correct as well
        console.log("pensionContract.getNextPlayer(charlie): ", pensionContract.getNextPlayer(charlie));
        console.log("pensionContract.getNextPlayer(alice): ", pensionContract.getNextPlayer(alice));
        console.log("pensionContract.getNextPlayer(bob): ", pensionContract.getNextPlayer(bob));

        assertEq(pensionContract.getNextPlayer(charlie), alice);
        assertEq(pensionContract.getNextPlayer(alice), bob);
        assertEq(pensionContract.getNextPlayer(bob), address(0));
    }

    function testClaimPension () public {
        dealTo(alice);
        vm.startPrank(alice);
        cash.createFlow(address(pensionContract), 1e6);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);

        console.log("time balance of alice: ", pensionContract.timeBalance(alice));
        console.log("flowrate of alice: ", uint256(int256(timePool.getMemberFlowRate(alice))));

        console.log("balance of app: ", cash.balanceOf(address(pensionContract)));
        console.log("totalPensionFlowRate: ", uint256(int256(pensionContract.totalPensionFlowRate())));

        vm.startPrank(alice);
        vm.expectRevert();
        pensionContract.claimPension();
        vm.stopPrank();

        console.log("time balance of alice: ", pensionContract.timeBalance(alice));
        console.log("flowrate of alice: ", uint256(int256(timePool.getMemberFlowRate(alice))));

        console.log("balance of app: ", cash.balanceOf(address(pensionContract)));
        console.log("totalPensionFlowRate: ", uint256(int256(pensionContract.totalPensionFlowRate())));

        
        vm.warp(block.timestamp + pensionContract.retirementAge());
        vm.startPrank(alice);
        console.log("claim pension");
        console.log("timeBalance(alice): \t", pensionContract.timeBalance(alice));
        console.log("retirementAge: \t", pensionContract.retirementAge());
        console.log("timeBalance(msg.sender) < retirementAge * 1e18: ", pensionContract.timeBalance(alice) < pensionContract.retirementAge());
        pensionContract.claimPension();
        cash.connectPool(pensionContract.cashPool());
        vm.stopPrank();

        console.log("balance of alice: ", cash.balanceOf(alice));
        console.log("cashPool.getTotalUnits: ", cashPool.getTotalUnits());
        console.log("cashPool.getMemberUnits(alice): ", cashPool.getUnits(alice));
        console.log("cashPool.getFlowRate(alice): ", uint256(int256(cashPool.getMemberFlowRate(alice))));
    }

    /*
    function testStreamWinningCondition() public {
        int96 aliceFlowRate = int96(1e6);
        int96 bobFlowRate = int96(2e6+1); // Bob streams at a higher rate

        dealTo(alice);
        dealTo(bob);

        vm.startPrank(alice);
        cash.createFlow(address(pensionContract), aliceFlowRate);
        vm.stopPrank();

        vm.startPrank(bob);
        cash.createFlow(address(pensionContract), bobFlowRate);
        vm.stopPrank();

        uint256 fourHours = 4 hours + 1 seconds;
        vm.warp(block.timestamp + fourHours);

        (,bool teamAWinning,) = pensionContract.teamA();
        (,bool teamBWinning,) = pensionContract.teamB();
        console.log("gameEnded: ", Time.unwrap(pensionContract.gameEnded()));
        assertFalse(Time.unwrap(pensionContract.gameEnded()) > 0, "GameEnded variable larger than zero");
        assertTrue(pensionContract.gameCanEnd(), "Game should have ended after 4 hours");
        assertFalse(teamAWinning, "Team A should not be winning");
        assertTrue(teamBWinning, "Team B should be winning");

        // Alice closes her stream
        vm.startPrank(alice);
        cash.deleteFlow(alice, address(pensionContract));
        vm.stopPrank();
        console.log("check if app was jailed");
        console.log(ISuperfluid(cash.getHost()).isAppJailed(ISuperApp(address(pensionContract))));

        console.log("gameEnded: ", Time.unwrap(pensionContract.gameEnded()));

        assertTrue(Time.unwrap(pensionContract.gameEnded()) > 0, "Game should have ended after Alice closes her stream post 4 hours");
    }

    function testCharlieShiftsBalanceToAliceOnStreamClose() public {
        int96 aliceFlowRate = int96(1e6);
        int96 bobFlowRate = int96(2e6 +1);
        int96 charlieFlowRate = int96(3e6); // Charlie streams at the highest rate

        dealTo(alice);
        dealTo(bob);
        dealTo(charlie);

        vm.startPrank(alice);
        cash.createFlow(address(pensionContract), aliceFlowRate);
        vm.stopPrank();

        vm.startPrank(bob);
        cash.createFlow(address(pensionContract), bobFlowRate);
        vm.stopPrank();

        vm.startPrank(charlie);
        cash.createFlow(address(pensionContract), charlieFlowRate);
        vm.stopPrank();

        uint256 twoHours = 2 hours + 1 seconds;
        vm.warp(block.timestamp + twoHours);

        // Charlie closes his stream before the game ends
        vm.startPrank(charlie);
        cash.deleteFlow(charlie, address(pensionContract));
        vm.stopPrank();

        uint256 balanceAliceAfter = pensionContract.balanceOf(alice);
        uint256 balanceCharlieAfter = pensionContract.balanceOf(charlie);

        console.log("balanceAliceAfter: ", balanceAliceAfter);
        console.log("balanceCharlieAfter: ", balanceCharlieAfter);

        assertTrue(balanceCharlieAfter == 0, "Charlie's balance should be 0 after closing the stream");
        assertTrue(balanceAliceAfter > 0, "Alice's balance should increase after Charlie closes his stream");
    }

    function testStreamDropoutBeforeGameCanEnd() public {
        int96 aliceFlowRate = int96(1e6);
        int96 bobFlowRate = int96(1e6+1);

        dealTo(alice);
        dealTo(bob);

        vm.startPrank(alice);
        cash.createFlow(address(pensionContract), aliceFlowRate);
        vm.stopPrank();

        vm.startPrank(bob);
        cash.createFlow(address(pensionContract), bobFlowRate);
        vm.stopPrank();

        uint256 oneHour = 1 hours;
        vm.warp(block.timestamp + oneHour);

        // Alice or Bob drops out before game can end
        vm.startPrank(alice);
        cash.deleteFlow(alice, address(pensionContract));
        vm.stopPrank();

        // Check if revert happens as expected
        bool end = pensionContract.gameCanEnd();
        console.log("Game can end: ", end);
        console.log("balance of alice: ", pensionContract.balanceOf(alice));
        console.log("balance of bob: ", pensionContract.balanceOf(bob));

        console.log("Test passed: Stream dropout before game can end doesn't revert");
    }


    function testFail_NonLeaderStartGameRevert() public {
        dealTo(charlie);
        vm.startPrank(charlie);
        int96 flowRate = int96(1e6);
        //vm.expectRevert();\
        cash.createFlow(address(pensionContract), flowRate);
    
        vm.stopPrank();
    }

    function testFail_UserAlreadyHadAStream() public {
        int96 aliceFlowRate = int96(1e6);
        int96 bobFlowRate = int96(2e6);
        int96 charlieFlowRate = int96(3e6); // Charlie streams at the highest rate

        dealTo(alice);
        dealTo(bob);
        dealTo(charlie);

        vm.startPrank(alice);
        cash.createFlow(address(pensionContract), aliceFlowRate);
        vm.stopPrank();

        vm.startPrank(bob);
        cash.createFlow(address(pensionContract), bobFlowRate);
        vm.stopPrank();

        vm.startPrank(charlie);
        cash.createFlow(address(pensionContract), charlieFlowRate);
        vm.stopPrank();

        uint256 oneHour = 1 hours;
        vm.warp(block.timestamp + oneHour);

        // Charlie closes his stream
        vm.startPrank(charlie);
        cash.deleteFlow(charlie, address(pensionContract));
        vm.stopPrank();

        // Charlie reopens his stream
        vm.startPrank(charlie);
        cash.createFlow(address(pensionContract), charlieFlowRate);
        vm.stopPrank();
    }

    function testPayouts() public {
        int96 r1 = int96(1e13);
        int96 r2 = int96(1e13)+1;
        int96 r3 = int96(1e13);
        int96 r4 = int96(1e13)+1;
        int96 r5 = int96(1e13);
        address[5] memory users = [alice, bob, charlie, daniel, emily];
        int96[5] memory flowRates = [r1, r2, r3, r4, r5];
        
        uint256 randomWarpTime = 45 minutes;

        dealTo(users[0]);
        vm.startPrank(users[0]);
        cash.createFlow(address(pensionContract), flowRates[0]);
        vm.stopPrank();
        dealTo(users[1]);
        vm.startPrank(users[1]);
        cash.createFlow(address(pensionContract), flowRates[1]);
        vm.stopPrank();
        // Randomly warp time between stream creations
        uint256 t0 = block.timestamp;
        uint256 t1 = t0 + randomWarpTime;
        vm.warp(t0 + randomWarpTime);

        // Create streams for each user
        for(uint i = 2; i < users.length; i++) {
            dealTo(users[i]);
            vm.startPrank(users[i]);
            cash.createFlow(address(pensionContract), flowRates[i]);
            vm.stopPrank();
            // Randomly warp time between stream creations
            vm.warp(block.timestamp + randomWarpTime);
            if(pensionContract.winningTeam().z == address(0x0)) {
                console.log("Team A is winning");
            } else {
                console.log("Team B is winning");
            }
            console.log("Time to end: ", pensionContract.timeToEnd());
        }

        console.log("all players are in the game. Now we can fast forward, and check payouts");
        // Warp enough time for the game to end
        console.log("calc inputs");
        console.log(pensionContract.timeToEnd());
        vm.warp(t1 + Time.unwrap(pensionContract.timeToEnd()) + 1);
        console.log("now the game should be able to end:");
        console.log(pensionContract.gameCanEnd());
        // Log everyone's balances
        for(uint i = 0; i < users.length; i++) {
            uint256 balance = pensionContract.balanceOf(users[i]);
            console.log(nameOf(users[i]), "'s\t in app credit:\t", balance/1e12);
        }
        for(uint i = 0; i < users.length; i++) {
            uint256 balanceOfToken = cash.balanceOf(users[i]);
            console.log(nameOf(users[i]), "'s\t token balance:\t", balanceOfToken/1e12);
        }
        for(uint i = 0; i < users.length; i++) {
            int96 flowRate = cash.getFlowRate(users[i], address(pensionContract));
            int128 internalFlowRate = pensionContract.getFlowRate(users[i]);
            console.log("external and internal flowrates for", nameOf(users[i]));
            console2.log(flowRate);
            console2.log(internalFlowRate);
        }
        // before closing user balances, we should try and guess what is gonna happen
        // check how much each user should get and then check if they get it 
        uint256 balanceOfAppBefore = cash.balanceOf(address(pensionContract));
        console.log("balanceOfAppBefore:\t", balanceOfAppBefore/1e12);
        console.log("app gameEndTime:\t", Time.unwrap(pensionContract.gameEnded()));

        for (uint i = 0; i < users.length; i++) {
            // Close one user's stream and calculate if they get enough
            console.log("CLOSING STREAM FOR %s", nameOf(users[i]));
            vm.startPrank(users[i]);
            cash.deleteFlow(users[i], address(pensionContract));
            vm.stopPrank();

            assertTrue(!ISuperfluid(cash.getHost()).isAppJailed(ISuperApp(address(pensionContract))));

            uint256 balanceAfterClosing = cash.balanceOf(users[i]);
            console.log(nameOf(users[i]), "'s\t balance after closing stream:\t", balanceAfterClosing/1e12);
            vm.warp(block.timestamp + 10000);
        }
        uint256 balanceOfAppAfter = cash.balanceOf(address(pensionContract));
        console.log("balanceOfAppAfter:\t", balanceOfAppAfter);
        console.log("app gameEndTime:\t", Time.unwrap(pensionContract.gameEnded()));
        console.log("check if app was jailed");
        console.log(ISuperfluid(cash.getHost()).isAppJailed(ISuperApp(address(pensionContract))));
    }

    struct Action {
        uint8 who;
        uint80 flowRate;
        uint16 dt;
    }

    function testFuzzShit(uint80 r1, uint80 r2, Action[8] memory actions) public {
        dealTo(users[0]);
        vm.startPrank(users[0]);
        cash.createFlow(address(pensionContract), int96(uint96(r1)) / 2 * 2 + 2);
        vm.stopPrank();

        dealTo(users[1]);
        vm.startPrank(users[1]);
        cash.createFlow(address(pensionContract), int96(uint96(r2)) / 2 * 2 + 1);
        vm.stopPrank();

        for (uint i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            // in this test case we exclude further actions from alice and bob. write another test case for those cases.
            address tester = users[action.who % (users.length - 2) + 2];
            dealTo(tester);
            if(pensionContract.gameCanEnd()){
                setFlow(tester, 0);
            } else {
                setFlow(tester, int96(uint96(action.flowRate)));
            }
            vm.warp(block.timestamp + uint32(action.dt));
            assertFalse(ISuperfluid(cash.getHost()).isAppJailed(pensionContract), "fucked");
        }
    }

    function setFlow(address tester, int96 flowRate) internal {
        vm.startPrank(tester);
        int96 currentFlowRate = cash.getFlowRate(tester, address(pensionContract));
        if(currentFlowRate == 0 && flowRate != 0) {
            if(!pensionContract.isUserBanned(tester)) {
                cash.createFlow(address(pensionContract), flowRate);
            }
        } else if(currentFlowRate != 0 && flowRate == 0) {
            cash.deleteFlow(tester, address(pensionContract));
        } else if(currentFlowRate != 0 && flowRate != 0) {
            if(currentFlowRate % 2 == flowRate % 2) {
                cash.updateFlow(address(pensionContract), flowRate);
            } else {
                cash.updateFlow(address(pensionContract), flowRate+1);
            }
        }
        vm.stopPrank();
    }
    */
}  
