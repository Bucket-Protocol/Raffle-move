// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::main {
    use raffle::drand_lib::{derive_randomness, verify_drand_signature, safe_selection};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use std::option::{Self, Option};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::linked_table::{Self, LinkedTable};
    
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use std::string::{Self};
    
    use sui::table::{Self, Table};
    use std::debug;

    struct Raffle <phantom T> has key, store {
        id: UID,
        round: u64,
        status: u8,
        participants: LinkedTable<address, u64>,
        participantsCount: u64,
        winnerCount: u64,
        winners: Option<address>,
        awardToken: Balance<T>,
    }
    /// Raffle status
    const IN_PROGRESS: u8 = 0;
    const COMPLETED: u8 = 1;

    
    fun init() {
    }

    public entry fun create_raffle<T>(round: u64, participants: vector<address>, winnerCount: u64, awardToken: Coin<T>, ctx: &mut TxContext){
        let table = linked_table::new<address, u64>(ctx);
        let participantsCount = vector::length(&participants);
        loop {
            if (vector::length(&participants) > 0) {
                let participant = vector::pop_back(&mut participants);
                linked_table::push_back(&mut table, participant, 0);
            } else {
                break
            }
        };
        
        let raffle: Raffle<T> = Raffle {
            id: object::new(ctx),
            round,
            status: IN_PROGRESS,
            participants: table,
            participantsCount: participantsCount,
            winnerCount,
            winners: option::none(),
            awardToken: coin::into_balance<T>(awardToken),
        };
        transfer::public_share_object(raffle);
    }

    public entry fun settle_raffle<T>(raffle: &mut Raffle<T>, drand_sig: vector<u8>, drand_prev_sig: vector<u8>, ctx: &mut TxContext){
        assert!(raffle.status != COMPLETED, 0);
        verify_drand_signature(drand_sig, drand_prev_sig, raffle.round);
        raffle.status = COMPLETED;
        // The randomness is derived from drand_sig by passing it through sha2_256 to make it uniform.
        let digest = derive_randomness(drand_sig);
        let random_number = 0;
        let i = 0;
        loop{
            if (i < raffle.participantsCount) {
                let random_number = safe_selection(raffle.participantsCount - i, &digest, random_number);
                debug::print(&random_number);
                i = i+1;
            } else {
                break;
            }
        };             
    }


    #[test]
    fun test_init() {
        use sui::test_scenario;
        // create test addresses representing users
        let admin = @0xad;
        let host = @0xac;
        let user1 = @0xCAFE;
        let user2 = @0xCAFF;
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        
        {
            init();
        };
        test_scenario::next_tx(scenario, admin);
        {
            let managerCap = test_scenario::take_from_sender<ManagerCap>(scenario);
            let participants = vector::new();
            create_raffle(1, vector::new(), 1, Coin::new(100), test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, managerCap);
            
        };
        test_scenario::next_tx(scenario, host);
        {
            let hostCap = test_scenario::take_from_sender<HostCap>(scenario);
            let userTable = test_scenario::take_shared<UserTable>(scenario);
            // charge_from_users(&hostCap, &mut userTable, test_scenario::ctx(scenario));
            
            test_scenario::return_to_sender(scenario, hostCap);
            test_scenario::return_shared(userTable);
        };
        test_scenario::end(scenario_val);
    }
}
