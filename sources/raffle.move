// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::raffle {
    use sui::clock::{Self, Clock};
    use raffle::drand_lib::{derive_randomness, verify_drand_signature, safe_selection, get_current_round_by_time};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use std::ascii::String as ASCIIString;
    use sui::event;
    use std::type_name;
    use sui::object::{Self, UID,ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;

    struct TimeEvent has copy, drop, store { 
        timestamp_ms: u64,
        expect_current_round: u64,
        round_will_use: u64,
    }

    entry fun get_drandlib_round(clock: &Clock) {
        let expect_current_round = get_current_round_by_time(clock::timestamp_ms(clock));
        let round_will_use = expect_current_round + 2;
        event::emit(TimeEvent {
            timestamp_ms: clock::timestamp_ms(clock),
            expect_current_round: expect_current_round,
            round_will_use: round_will_use,
        });
    }
    
    struct CoinRaffleCreated has copy, drop {
        raffle_id: ID,
        raffle_name: String,
        creator: address,
        round: u64,
        participants_count: u64,
        winnerCount: u64,
        prizeAmount: u64,
        prizeType: ASCIIString,
    }
    public fun emit_coin_raffle_created<T>(raffle: &Raffle<T>) {
        let raffleType = type_name::into_string(type_name::get<T>());
        let raffleId = *object::borrow_id(raffle);
        event::emit(CoinRaffleCreated {
            raffle_id: raffleId,
            raffle_name: raffle.name,
            creator: raffle.creator,
            round: raffle.round,
            participants_count: vector::length(&raffle.participants),
            winnerCount: raffle.winnerCount,
            prizeAmount: balance::value(&raffle.balance),
            prizeType: raffleType,
            }
        );
    }

    struct CoinRaffleSettled has copy, drop {
        raffle_id: ID,
        settler: address,
    }
    public fun emit_coin_raffle_settled<T>(raffle: &Raffle<T>) {
        let raffleId = *object::borrow_id(raffle);
        event::emit(CoinRaffleSettled {
            raffle_id: raffleId,
            settler: raffle.settler,
            }
        );
    }

    struct Raffle <phantom T> has key, store {
        id: UID,
        name: String,
        round: u64,
        status: u8,
        creator: address,
        settler: address,
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

    public entry fun create_coin_raffle<T>(
        name: vector<u8>, 
        clock: &Clock,
        participants: vector<address>, 
        winnerCount: u64,
        awardObject: Coin<T>, 
        ctx: &mut TxContext
    ){
        assert!(winnerCount <= vector::length(&participants), 0);
        let drand_current_round = get_current_round_by_time(clock::timestamp_ms(clock));
        let raffle: Raffle<T> = Raffle {
            id: object::new(ctx),
            name: string::utf8(name),
            round: drand_current_round + 2,
            status: IN_PROGRESS,
            creator: tx_context::sender(ctx),
            settler: @0x00,
            participants: participants,
            winnerCount,
            winners: vector::empty(),
            balance: coin::into_balance<T>(awardObject),
        };
        emit_coin_raffle_created(&raffle);
        transfer::public_share_object(raffle);
    }

    public entry fun settle_coin_raffle<T>(raffle: &mut Raffle<T>, drand_sig: vector<u8>, drand_prev_sig: vector<u8>, ctx: &mut TxContext){
        assert!(raffle.status != COMPLETED, 0);
        verify_drand_signature(drand_sig, drand_prev_sig, raffle.round);
        raffle.status = COMPLETED;
        raffle.settler = tx_context::sender(ctx);
        // The randomness is derived from drand_sig by passing it through sha2_256 to make it uniform.
        let digest = derive_randomness(drand_sig);
        let random_number = 0;
        let i = 0;

        
        let award_per_winner = balance::value(&raffle.balance) / raffle.winnerCount;

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
            if (i < raffle.winnerCount) {
                transfer::public_transfer(coin::take(&mut raffle.balance, award_per_winner, ctx), winner);
            } else {
                let remain_balance = balance::value(&raffle.balance);
                transfer::public_transfer(coin::take( &mut raffle.balance, remain_balance, ctx), winner);
                break
            }
        };
        emit_coin_raffle_settled(raffle);
    }
    fun getWinners<T>(raffle: &Raffle<T>):vector<address> {
        raffle.winners
    }

    #[test]
    fun test_init() {
        use raffle::test_coin::{Self, TEST_COIN};
        use sui::test_scenario;
        use sui::balance;
        use std::debug;
        // create test addresses representing users
        let admin = @0xad;
        let host = @0xac;
        let user1 = @0xCAF1;
        let user2 = @0xCAF2;
        let user3 = @0xCAF3;
        let user4 = @0xCAF4;
        let user5 = @0xCAF5;
        let user6 = @0xCAF6;
        let user7 = @0xCAF7;
        let clockObj = @0x6;
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
            // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
        };

        test_scenario::next_tx(scenario, host);
        let winnerCount = 3;
        let totalPrize = 10;
        
        {
            let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(totalPrize), test_scenario::ctx(scenario));
            let participants = vector::empty<address>();
            vector::push_back(&mut participants, user1);
            vector::push_back(&mut participants, user2);
            vector::push_back(&mut participants, user3);
            vector::push_back(&mut participants, user4);
            vector::push_back(&mut participants, user5);
            vector::push_back(&mut participants, user6);
            vector::push_back(&mut participants, user7);
            let clockObj = clock::create_for_testing(test_scenario::ctx(scenario));
            // TODO: 我要找到測試用的 round 的 timestamp，然後寫上去，完成測試
            clock::set_for_testing(&mut clockObj, 1000);
            create_coin_raffle(b"TEST", &clockObj, participants, winnerCount, coin, test_scenario::ctx(scenario));
            
        };
        test_scenario::next_tx(scenario, user1);
        {
            let raffle = test_scenario::take_shared<Raffle<TEST_COIN>>(scenario);
            
            settle_coin_raffle(
                &mut raffle, 
                x"9443823f383e66ab072215da88087c31b129c350f9eebb0651f62da462e19b38d4a35c2f65d825304868d756ed81585016b9e847cf5c51a325e0d02519106ce1999c9292aa8b726609d792a00808dc9e9810ae76e9622e44934d14be32ef9c62",
                x"89aa680c3cde91517dffd9f81bbb5c78baa1c3b4d76b1bfced88e7d8449ff0dc55515e09364db01d05d62bde03a7d08111f95131a7fef2a27e1c8aea8e499189214d38d27deabaf67b35821949fff73b13f0f182588fe1dc73630742bb95ba29", 
                test_scenario::ctx(scenario)
            );
            let winners = getWinners(&raffle);
            debug::print(&winners);
            assert!(winnerCount == vector::length(&winners), 0);
            
            test_scenario::return_shared(raffle);
        };
        test_scenario::next_tx(scenario, user1);
        {
            assert!(totalPrize / winnerCount == 3, 0);
            let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user1);
            assert!(balance::value(coin::balance(&coin1)) == totalPrize / winnerCount, 0);
            test_scenario::return_to_address(user1, coin1);
            let coin2 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user2);
            assert!(balance::value(coin::balance(&coin2)) == totalPrize / winnerCount, 0);
            debug::print(&balance::value(coin::balance(&coin2)));
            test_scenario::return_to_address(user2, coin2);
            let coin7 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, user7);
            assert!(balance::value(coin::balance(&coin7)) == totalPrize - (totalPrize / winnerCount)*(winnerCount - 1), 0);
            test_scenario::return_to_address(user7, coin7);
        };
        // {
        //     // let coin1 = test_scenario::take_from_address<TEST_COIN>(scenario, user1);
        //     // assert!(balance::value(&coin1) == 0, 0);
        // }
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
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
}
