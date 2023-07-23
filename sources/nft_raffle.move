// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::nft_raffle {
    use raffle::drand_lib::{derive_randomness, verify_drand_signature, safe_selection};
    use sui::object::{Self, UID};
    use sui::table_vec::{Self, TableVec};
    use sui::transfer;
    use std::string::String;
    use sui::tx_context::{TxContext};
    use std::vector;
    use std::string::{Self};
    
    struct NFT_Raffle <phantom T: store + key> has key, store {
        id: UID,
        name: String,
        round: u64,
        status: u8,
        participants: vector<address>,
        reward_nfts: TableVec<T>,
        winner_count: u64,
        winners: vector<address>,
    }
    /// Raffle status
    const IN_PROGRESS: u8 = 0;
    const COMPLETED: u8 = 1;

    public entry fun create_nft_raffle<T: store + key>(
        name: vector<u8>,
        round: u64,
        participants: vector<address>, 
        reward_nfts_vec: vector<T>, 
        ctx: &mut TxContext
    ){
        let winner_count = vector::length(&reward_nfts_vec);
        let idx: u64 = 0;
        let reward_nfts = table_vec::empty(ctx);
        while (!vector::is_empty(&reward_nfts_vec)) {
            let nft = vector::pop_back(&mut reward_nfts_vec);
            table_vec::push_back(&mut reward_nfts, nft);
            idx = idx + 1;
        };
        let raffle: NFT_Raffle<T> = NFT_Raffle {
            id: object::new(ctx),
            name: string::utf8(name),
            round,
            status: IN_PROGRESS,
            participants: participants,
            reward_nfts: reward_nfts,
            winner_count: winner_count,
            winners: vector::empty(),
        };
        transfer::public_share_object(raffle);
        vector::destroy_empty(reward_nfts_vec);
    }

    public entry fun settle_nft_raffle<T: store + key>(
        raffle: &mut NFT_Raffle<T>, 
        drand_sig: vector<u8>, 
        drand_prev_sig: vector<u8>, 
    ) {
        assert!(raffle.status != COMPLETED, 0);
        verify_drand_signature(drand_sig, drand_prev_sig, raffle.round);
        raffle.status = COMPLETED;
        // The randomness is derived from drand_sig by passing it through sha2_256 to make it uniform.
        let digest = derive_randomness(drand_sig);
        let random_number = 0;
        let i = 0;
        loop{
            i = i+1;
            let length = vector::length(&raffle.participants);
            let random_number = safe_selection(length, &digest, random_number);
            vector::swap(&mut raffle.participants, random_number, length - 1);
            let winner = vector::pop_back(&mut raffle.participants);
            vector::push_back<address>(
                &mut raffle.winners, 
                winner,
            );
            let nft = table_vec::pop_back(&mut raffle.reward_nfts);
            if (i < raffle.winner_count) {
                transfer::public_transfer(nft, winner);
            } else {
                transfer::public_transfer(nft, winner);
                break
            }
        };
    }
    fun getWinners<T: key+store>(raffle: &NFT_Raffle<T>):vector<address> {
        raffle.winners
    }

    // #[test]
    // fun test_init() {
    //     use raffle::test_coin::{Self, TEST_COIN};
    //     use sui::test_scenario;
    //     use sui::balance;
    //     use std::debug;
    //     // create test addresses representing users
    //     let admin = @0xad;
    //     let host = @0xac;
    //     let user1 = @0xCAF1;
    //     let user2 = @0xCAF2;
    //     let user3 = @0xCAF3;
    //     let user4 = @0xCAF4;
    //     let user5 = @0xCAF5;
    //     let user6 = @0xCAF6;
    //     let user7 = @0xCAF7;
    //     // first transaction to emulate module initialization
    //     let scenario_val = test_scenario::begin(admin);
    //     let scenario = &mut scenario_val;
    //     {
    //         init(test_scenario::ctx(scenario));
    //         // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
    //     };

    //     test_scenario::next_tx(scenario, host);
    //     let winner_count = 3;
    //     let totalPrize = 10;
    //     {
    //         let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(totalPrize), test_scenario::ctx(scenario));
    //         let participants = vector::empty<address>();
    //         vector::push_back(&mut participants, user1);
    //         vector::push_back(&mut participants, user2);
    //         vector::push_back(&mut participants, user3);
    //         vector::push_back(&mut participants, user4);
    //         vector::push_back(&mut participants, user5);
    //         vector::push_back(&mut participants, user6);
    //         vector::push_back(&mut participants, user7);
            
    //         create_raffle(b"TEST", 3084797, participants, winner_count, coin, test_scenario::ctx(scenario));
            
    //     };
    //     test_scenario::next_tx(scenario, user1);
    //     {
    //         let raffle = test_scenario::take_shared<NFT_Raffle<TEST_COIN>>(scenario);
    //         settle_coin_raffle(
    //             &mut raffle, 
    //             x"9443823f383e66ab072215da88087c31b129c350f9eebb0651f62da462e19b38d4a35c2f65d825304868d756ed81585016b9e847cf5c51a325e0d02519106ce1999c9292aa8b726609d792a00808dc9e9810ae76e9622e44934d14be32ef9c62",
    //             x"89aa680c3cde91517dffd9f81bbb5c78baa1c3b4d76b1bfced88e7d8449ff0dc55515e09364db01d05d62bde03a7d08111f95131a7fef2a27e1c8aea8e499189214d38d27deabaf67b35821949fff73b13f0f182588fe1dc73630742bb95ba29", 
    //             test_scenario::ctx(scenario)
    //         );
    //         let winners = getWinners(&raffle);
    //         debug::print(&winners);
    //         assert!(winner_count == vector::length(&winners), 0);
            
    //         test_scenario::return_shared(raffle);
    //     };
    //     test_scenario::next_tx(scenario, user1);
    //     {
    //         assert!(totalPrize / winner_count == 3, 0);
    //         let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user1);
    //         assert!(balance::value(coin::balance(&coin1)) == totalPrize / winner_count, 0);
    //         test_scenario::return_to_address(user1, coin1);
    //         let coin2 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user2);
    //         assert!(balance::value(coin::balance(&coin2)) == totalPrize / winner_count, 0);
    //         debug::print(&balance::value(coin::balance(&coin2)));
    //         test_scenario::return_to_address(user2, coin2);
    //         let coin7 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user7);
    //         assert!(balance::value(coin::balance(&coin7)) == totalPrize - (totalPrize / winner_count)*(winner_count - 1), 0);
    //         test_scenario::return_to_address(user7, coin7);
    //     };
    //     // {
    //     //     // let coin1 = test_scenario::take_from_address<TEST_COIN>(scenario, user1);
    //     //     // assert!(balance::value(&coin1) == 0, 0);
    //     // }
    //     // {
    //     //     let managerCap = test_scenario::take_from_sender<ManagerCap>(scenario);
    //     //     let participants = vector::new();
    //     //     create_raffle(1, vector::new(), 1, Coin::new(100), test_scenario::ctx(scenario));
    //     //     test_scenario::return_to_sender(scenario, managerCap);
            
    //     // };
    //     // test_scenario::next_tx(scenario, host);
    //     // {
    //     //     let hostCap = test_scenario::take_from_sender<HostCap>(scenario);
    //     //     let userTable = test_scenario::take_shared<UserTable>(scenario);
    //     //     // charge_from_users(&hostCap, &mut userTable, test_scenario::ctx(scenario));
            
    //     //     test_scenario::return_to_sender(scenario, hostCap);
    //     //     test_scenario::return_shared(userTable);
    //     // };
    //     test_scenario::end(scenario_val);
    // }
}
