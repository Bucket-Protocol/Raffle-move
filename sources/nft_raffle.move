// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::nft_raffle {
    use sui::clock::{Self, Clock};
    use raffle::drand_lib::{derive_randomness, verify_drand_signature, safe_selection, get_current_round_by_time};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID, UID};
    use sui::object_table::{Self, ObjectTable};
    use sui::transfer;
    use sui::event;
    use std::type_name;
    use std::string::String;
    use std::ascii::String as ASCIIString;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use std::string::{Self};
    use raffle::addresses_obj::{Self, AddressesObj};
    
    struct NFT_Raffle <phantom T: store + key> has key, store {
        id: UID,
        name: String,
        round: u64,
        status: u8,
        creator: address,
        settler: address,
        participants: vector<address>,
        reward_nfts: ObjectTable<ID, T>,
        reward_nfts_table_keys: vector<ID>,
        winnerCount: u64,
        winners: vector<address>,
    }
    /// Raffle status
    const IN_PROGRESS: u8 = 0;
    const COMPLETED: u8 = 1;

    
    fun init(_ctx: &mut TxContext) {
    }

    struct NftRaffleCreated has copy, drop {
        raffle_id: ID,
        raffle_name: String,
        creator: address,
        round: u64,
        participants_count: u64,
        participants: vector<address>,
        winnerCount: u64,
        prizeType: ASCIIString,
        reward_nft_ids: vector<ID>,
    }
    public fun emit_nft_raffle_created<T: store + key>(raffle: &NFT_Raffle<T>) {
        let raffleType = type_name::into_string(type_name::get<T>());
        let raffleId = *object::borrow_id(raffle);
        let participants_in_event = vector::empty<address>();
        let i = 0;
        let length = vector::length(&raffle.participants);
        loop{
            let participant = vector::borrow(&raffle.participants, i);
            vector::push_back(&mut participants_in_event, *participant);
            i = i+1;
            if (i == length) {
                break
            }
        };
        event::emit(NftRaffleCreated {
            raffle_id: raffleId,
            raffle_name: raffle.name,
            creator: raffle.creator,
            round: raffle.round,
            participants_count: vector::length(&raffle.participants),
            participants: participants_in_event,
            winnerCount: raffle.winnerCount,
            prizeType: raffleType,
            reward_nft_ids: raffle.reward_nfts_table_keys,
            }
        );
    }
    struct NftRaffleSettled has copy, drop {
        raffle_id: ID,
        settler: address,
    }
    public fun emit_nft_raffle_settled<T: store + key>(raffle: &NFT_Raffle<T>) {
        let raffleId = *object::borrow_id(raffle);
        event::emit(NftRaffleSettled {
            raffle_id: raffleId,
            settler: raffle.settler,
            }
        );
    }

public entry fun create_nft_raffle_by_addresses_obj<T: store + key, F: drop>(
        name: vector<u8>,
        clock: &Clock,
        addressesObj: &mut AddressesObj<F>,
        fee: Coin<F>,
        reward_nfts_vec: vector<T>, 
        ctx: &mut TxContext
    ){
        assert!(addresses_obj::getFee(addressesObj) == balance::value(coin::balance(&fee)), 0);
        transfer::public_transfer(fee, addresses_obj::getCreator(addressesObj));
        
        let participants = addresses_obj::update_adresses_and_return_old(addressesObj, vector::empty());
        create_nft_raffle(name, clock, participants, reward_nfts_vec, ctx);
    }
    public entry fun create_nft_raffle<T: store + key>(
        name: vector<u8>,
        clock: &Clock,
        participants: vector<address>, 
        reward_nfts_vec: vector<T>, 
        ctx: &mut TxContext
    ){
        let drand_current_round = get_current_round_by_time(clock::timestamp_ms(clock));
        let winnerCount = vector::length(&reward_nfts_vec);
        assert!(winnerCount <= vector::length(&participants), 0);
        let idx: u64 = 0;
        let reward_nfts = object_table::new(ctx);
        let reward_nfts_table_keys = vector::empty<ID>();
        while (!vector::is_empty(&reward_nfts_vec)) {
            let nft = vector::pop_back(&mut reward_nfts_vec);
            let id = object::id(&nft);
            object_table::add(&mut reward_nfts, id, nft);
            vector::push_back(&mut reward_nfts_table_keys, id);
            idx = idx + 1;
        };
        let raffle: NFT_Raffle<T> = NFT_Raffle {
            id: object::new(ctx),
            name: string::utf8(name),
            round: drand_current_round + 2,
            status: IN_PROGRESS,
            creator: tx_context::sender(ctx),
            settler: @0x00,
            participants: participants,
            reward_nfts: reward_nfts,
            reward_nfts_table_keys: reward_nfts_table_keys,
            winnerCount: winnerCount,
            winners: vector::empty(),
        };
        emit_nft_raffle_created(&raffle);
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
            let id = vector::pop_back(&mut raffle.reward_nfts_table_keys);
            let nft = object_table::remove(&mut raffle.reward_nfts, id);
            if (i < raffle.winnerCount) {
                transfer::public_transfer(nft, winner);
            } else {
                transfer::public_transfer(nft, winner);
                break
            }
        };
        raffle.participants = vector::empty();
        emit_nft_raffle_settled(raffle);
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
    //     let winnerCount = 3;
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
            
    //         create_raffle(b"TEST", 3084797, participants, winnerCount, coin, test_scenario::ctx(scenario));
            
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
    //         assert!(winnerCount == vector::length(&winners), 0);
            
    //         test_scenario::return_shared(raffle);
    //     };
    //     test_scenario::next_tx(scenario, user1);
    //     {
    //         assert!(totalPrize / winnerCount == 3, 0);
    //         let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user1);
    //         assert!(balance::value(coin::balance(&coin1)) == totalPrize / winnerCount, 0);
    //         test_scenario::return_to_address(user1, coin1);
    //         let coin2 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user2);
    //         assert!(balance::value(coin::balance(&coin2)) == totalPrize / winnerCount, 0);
    //         debug::print(&balance::value(coin::balance(&coin2)));
    //         test_scenario::return_to_address(user2, coin2);
    //         let coin7 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user7);
    //         assert!(balance::value(coin::balance(&coin7)) == totalPrize - (totalPrize / winnerCount)*(winnerCount - 1), 0);
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
