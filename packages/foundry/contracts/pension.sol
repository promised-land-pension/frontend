// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {SuperAppBaseFlow} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBaseFlow.sol";
import {BasicParticle, SemanticMoney, FlowRate, Value, Time} from "@superfluid-finance/solidity-semantic-money/src/SemanticMoney.sol";
import {StorageLib, Storage} from "./storageLib.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";

interface IMintableSuperToken {
    function burn(uint256 amount) external;
}

contract Pensions is SuperAppBaseFlow {
    using SemanticMoney for BasicParticle;
    using SuperTokenV1Library for ISuperToken;
    using SafeCast for uint256;
    using StorageLib for Storage;

    /****

    - users stream to the contract, which keeps track of the amount streamed by sendin back TIME tokens
    - the speed is based on the speed of the top streamer
    - everyone else is slowed down as a result (but they keep accruing)
    - Because the top streamer could drop out, we keep an ordered list of users (based on flowrate)
    - When a user reaches the threshold, they can claim a pension (extra tx). Then the threshold is moved 
    - The pension is a GDA stream, modulated to keep the stream alive

    - while the token is left transferrable, we only take into account "unclaimed" $TIME. so if they claim it, they lose it


    WISHLIST:
    - Referees give you a speed boost

    ****/

    Storage public workers;
    Storage public pensioners;

    function getWorkerHead() public view returns (address) {
        return workers.head;
    }

    function getPensionersHead() public view returns (address) {
        return pensioners.head;
    }

    uint256 public retirementAge = 60*60*24; // 24 hours in seconds. 
    
    int96 public constant SCALING_FACTOR = 1e6;

    ISuperToken immutable public cash;
    ISuperToken immutable public time;
    ISuperfluidPool immutable public timePool;
    ISuperfluidPool immutable public cashPool;

    mapping(ISuperToken => bool) internal _acceptedSuperTokens;

    constructor
        (ISuperToken _cash, ISuperToken _time) 
        SuperAppBaseFlow(ISuperfluid(_cash.getHost()), true, true, true, string("")) {
            //selfRegister(true,true,true);
            cash = _cash;
            _acceptedSuperTokens[cash] = true;
            // make sure this contract has been given a bunch of time tokens
            time = _time;
            // create a GDA
            timePool = time.createPool(address(this), PoolConfig({transferabilityForUnitsOwner: false, distributionFromAnyAddress: false}));
            cashPool = cash.createPool(address(this), PoolConfig({transferabilityForUnitsOwner: false, distributionFromAnyAddress: true}));
        }
    
    /* TIME AUCTION HELPERS */ 
    function updateTimeUnits(address sender) internal {
        int96 flowrate = workers.list[sender].flowrate;
        uint128 units = uint128(int128(flowrate / SCALING_FACTOR));
        timePool.updateMemberUnits(sender, units);
    }

    function adjustTIMEFlowrate(address sender, bytes memory ctx) internal returns(bytes memory newCtx) {
        // Top streamer should get 1 TIME per hour
        // everyone else should be adjusted accordingly
        uint128 totalUnits = timePool.getTotalUnits();
        int96 benchmarkTIME = 1e18;
        // units are equivalent to the user's flowrate, so we can assume 
        uint128 headUnits = timePool.getUnits(workers.head); 
        // per unit, should be benchmarkTIME / units
        int96 TIMEperUnit = benchmarkTIME / int96(int128(headUnits)); 
        int96 totalFlow = TIMEperUnit * int96(int128(totalUnits));
        // we need to make sure that the user is getting a TIMEPerHour flowrate
        
        newCtx = time.distributeFlowWithCtx(
            address(this),
            timePool,
            totalFlow,
            ctx
        );
    }

    /* PENSION claiming functions */ 
    function claimPension() public {
        // check if the user has reached retirement age
        // if they have, claim the pension
        // if they have not, revert
        if(timeBalance(msg.sender) < retirementAge*1e18) revert("Not retired");
        // claim the pension
        // remove user from the list
        // add them to adifferent list? 
        workers.removePlayer(msg.sender); // removed them from the list
        updateTimeUnits(msg.sender); // removes their TIME flow
        cashPool.updateMemberUnits(msg.sender, 1);
        cash.distributeFlow(address(this), cashPool, totalPensionFlowRate());
        retirementAge += 3600;
    }

    function totalPensionFlowRate() public view returns (int96) {
        uint256 totalCashBalance = cash.balanceOf(address(this));
        return int96(int256(totalCashBalance / retirementAge));
    }

    /* PENSION payment functions */
    

    /* FLOW CALLBACKS */

    function onFlowCreated(ISuperToken, /*superToken*/ address sender, bytes calldata ctx)
        internal
        override
        returns (bytes memory)
    {
        int96 flowRate = cash.getFlowRate(sender, address(this));
        workers.addPlayer(sender, flowRate);
        updateTimeUnits(sender);
        return adjustTIMEFlowrate(sender, ctx);
    }

    // UPDATE
    function onFlowUpdated(
        ISuperToken, /*superToken*/
        address sender,
        int96 previousFlowRate,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        int96 flowRate = cash.getFlowRate(sender, address(this));
        workers.updatePlayer(sender, flowRate);
        updateTimeUnits(sender);
        return adjustTIMEFlowrate(sender, ctx);
    }

    // DELETE
    function onFlowDeleted(
        ISuperToken, /*superToken*/
        address sender,
        address receiver,
        int96 previousFlowRate,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        if(receiver != address(this)) return ctx;
        workers.removePlayer(sender);
        updateTimeUnits(sender);
        return adjustTIMEFlowrate(sender, ctx);
    }

    /* HELPERS */
    /**
     * @notice a function to return the time balance of a player
     * @param p The player.
     * @return tb The time balance.
     */
    function timeBalance(address p) public view returns (uint256) {
        (int256 claimableBalance, ) = timePool.getClaimableNow(p);
        return uint256(claimableBalance);
    }

    function getNextPlayer(address p) public view returns (address) {
        return workers.list[p].next;
    }
}