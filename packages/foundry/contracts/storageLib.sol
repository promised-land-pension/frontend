// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {BasicParticle, SemanticMoney, FlowRate, Value, Time} from "@superfluid-finance/solidity-semantic-money/src/SemanticMoney.sol";

struct User {
    address before;
    address next;
    int96 flowrate;
}

struct Storage {
    mapping(address => User) list;
    address head;
}

//type Storage is Data;

library StorageLib {
    /**
     * @notice a 
     * @param data The users struct.
     * @param p The player.
     * @param f The flowrate.
     */
    function addPlayer(Storage storage data, address p, int96 f) internal {
        if(data.head == address(0)){
            data.head = p; 
            data.list[p].flowrate = f;
            return;
        } 
        if(data.list[data.head].next == address(0)){
            if(data.list[data.head].flowrate < f){
                data.list[data.head].next = p;
                data.list[p].before = data.head;
                data.list[p].flowrate = f;
            } else {
                data.list[data.head].next = p;
                data.list[p].before = data.head;
                data.list[p].flowrate = f;
            }
            return;
        }
        // check if there is a head. If there isn't, this is the first user        
        for (address i = data.head; i != address(0); i = data.list[i].next) {
            if (data.list[i].flowrate < f) {
                if(i == data.head) {
                    data.head = p;
                }
                data.list[p].next = i;
                data.list[p].before = data.list[i].before;
                data.list[i].before = p;
                data.list[p].flowrate = f;
                return;
            }
        }
    }

    function updatePlayer(Storage storage data, address p, int96 f) internal {
        removePlayer(data, p);
        addPlayer(data, p, f);
    }

    function removePlayer(Storage storage data, address p) internal {
        data.list[data.list[p].before].next = data.list[p].next;
        data.list[data.list[p].next].before = data.list[p].before;
        if (data.head == p) data.head = data.list[p].next;
        delete data.list[p];
    }

}

//using LibScaler for Scaler global;