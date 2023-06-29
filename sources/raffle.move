// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::raffle {
    use raffle::drand_lib::{derive_randomness, verify_drand_signature, safe_selection};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use std::option::{Self};
    // use sui::sui::SUI;
    use sui::transfer;
    
    use std::string::String;
    
    use sui::tx_context::{TxContext};
    use std::vector;
    use std::string::{Self};
    
    use sui::table::{Self, Table};

    struct Raffle <phantom T> has key, store {
        id: UID,
        name: String,
        round: u64,
        status: u8,
        participants: vector<address>,
        winnerCount: u64,
        winners: vector<address>,
        balance: Balance<T>,
    }
    /// Raffle status
    const IN_PROGRESS: u8 = 0;
    const COMPLETED: u8 = 1;

    
    fun init(_ctx: &mut TxContext) {
    }

    public entry fun create_raffle<T>(name: vector<u8>, round: u64, participants: vector<address>, winnerCount: u64, awardObject: Coin<T>, ctx: &mut TxContext){
        let raffle: Raffle<T> = Raffle {
            id: object::new(ctx),
            name: string::utf8(name),
            round,
            status: IN_PROGRESS,
            participants: participants,
            winnerCount,
            winners: vector::empty(),
            balance: coin::into_balance<T>(awardObject),
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

        
        let award_per_winner = balance::value(&raffle.balance) / raffle.winnerCount;

        loop{
            let length = vector::length(&raffle.participants);
            let random_number = safe_selection(length, &digest, random_number);
            vector::swap(&mut raffle.participants, random_number, length - 1);
            let winner = vector::pop_back(&mut raffle.participants);
            vector::push_back<address>(
                &mut raffle.winners, 
                winner,
            );
            if (i < raffle.winnerCount) {
                transfer::public_transfer(coin::take(&mut raffle.balance, award_per_winner, ctx), winner);
                i = i+1;
            } else {
                let remain_balance = balance::value(&raffle.balance);
                transfer::public_transfer(coin::take( &mut raffle.balance, remain_balance, ctx), winner);
                break
            }
        };
    }

    #[test]
    fun test_init() {
        use raffle::test_coin::{Self, TEST_COIN};
        use sui::test_scenario;
        use sui::balance;
        // create test addresses representing users
        let admin = @0xad;
        let host = @0xac;
        let user1 = @0xCAFA;
        let user2 = @0xCAFB;
        let user3 = @0xCAFC;
        let user4 = @0xCAFD;
        let user5 = @0xCAFE;
        let user6 = @0xCAFF;
        let user7 = @0xCAFAA;
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
            // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
        };

        test_scenario::next_tx(scenario, host);
        {
            let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(10), test_scenario::ctx(scenario));
            let participants = vector::empty<address>();
            vector::push_back(&mut participants, user1);
            vector::push_back(&mut participants, user2);
            vector::push_back(&mut participants, user3);
            vector::push_back(&mut participants, user4);
            vector::push_back(&mut participants, user5);
            vector::push_back(&mut participants, user6);
            vector::push_back(&mut participants, user7);
            
            create_raffle(b"TEST", 3084797, participants, 3, coin, test_scenario::ctx(scenario));
            
        };
        test_scenario::next_tx(scenario, user1);
        {
            let raffle = test_scenario::take_shared<Raffle<TEST_COIN>>(scenario);
            settle_raffle(
                &mut raffle, 
                x"9443823f383e66ab072215da88087c31b129c350f9eebb0651f62da462e19b38d4a35c2f65d825304868d756ed81585016b9e847cf5c51a325e0d02519106ce1999c9292aa8b726609d792a00808dc9e9810ae76e9622e44934d14be32ef9c62",
                x"89aa680c3cde91517dffd9f81bbb5c78baa1c3b4d76b1bfced88e7d8449ff0dc55515e09364db01d05d62bde03a7d08111f95131a7fef2a27e1c8aea8e499189214d38d27deabaf67b35821949fff73b13f0f182588fe1dc73630742bb95ba29", 
                test_scenario::ctx(scenario)
            );
            test_scenario::return_shared(raffle);
        };
        // {
        //     let managerCap = test_scenario::take_from_sender<ManagerCap>(scenario);
        //     let participants = vector::new();
        //     create_raffle(1, vector::new(), 1, Coin::new(100), test_scenario::ctx(scenario));
        //     test_scenario::return_to_sender(scenario, managerCap);
            
        // };
        // test_scenario::next_tx(scenario, host);
        // {
        //     let hostCap = test_scenario::take_from_sender<HostCap>(scenario);
        //     let userTable = test_scenario::take_shared<UserTable>(scenario);
        //     // charge_from_users(&hostCap, &mut userTable, test_scenario::ctx(scenario));
            
        //     test_scenario::return_to_sender(scenario, hostCap);
        //     test_scenario::return_shared(userTable);
        // };
        test_scenario::end(scenario_val);
    }
}
