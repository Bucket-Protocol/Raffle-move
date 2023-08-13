// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::addresses_obj {
    friend raffle::nft_raffle;
    friend raffle::raffle;
    
    use sui::clock::{Self, Clock};
    use raffle::drand_lib::{derive_randomness, verify_drand_signature, safe_selection, get_current_round_by_time};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use std::ascii::String as ASCIIString;
    use sui::event;
    use std::type_name;
    use sui::object::{Self, ID, UID};
    use sui::object_table::{Self, ObjectTable};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;


    struct AddressesSubObj has key, store {
        id: UID,
        addresses: vector<address>,
    }
    struct AddressesObj<phantom T> has key, store {
        id: UID,
        addressesSubObjs_table: ObjectTable<ID, AddressesSubObj>,
        addressesSubObjs_keys: vector<ID>,
        creator: address,
        fee: u64,
    }

    public (friend) fun internal_create<T>(
        participants: vector<address>,
        ctx: &mut TxContext
    ): AddressesObj<T> {
        let addressesSubObj = AddressesSubObj {
            id: object::new(ctx),
            addresses: participants,
        };

        let addressesSubObjs_table = object_table::new<ID, AddressesSubObj>(ctx);
        let addressesSubObjs_keys = vector::empty<ID>();
        
        let id = object::id(&addressesSubObj);
        object_table::add(&mut addressesSubObjs_table, id, addressesSubObj);
        vector::push_back(&mut addressesSubObjs_keys, id);
        
        // object_table::add(&mut reward_nfts, id, nft);
        let addressesObj = AddressesObj<T> {
            id: object::new(ctx),
            addressesSubObjs_table,
            addressesSubObjs_keys,
            creator: tx_context::sender(ctx),
            fee:0,
        };
        return addressesObj
    }
    public entry fun create<T>(
        participants: vector<address>,
        ctx: &mut TxContext
    ){
        let addressesObj = internal_create<T>(participants, ctx);
        transfer::transfer(addressesObj, tx_context::sender(ctx));
    }
    
    public entry fun add_addresses<T>(
        addressesObj: &mut AddressesObj<T>,
        addresses: vector<address>, 
        ctx: &mut TxContext
    ){
        let id = vector::borrow(
            &addressesObj.addressesSubObjs_keys, 
            vector::length(&addressesObj.addressesSubObjs_keys) - 1,
        );
        let latestSubObj = object_table::borrow_mut(&mut addressesObj.addressesSubObjs_table, *id);
        if(vector::length(&latestSubObj.addresses) > 7500){
            let addressesSubObj = AddressesSubObj {
                id: object::new(ctx),
                addresses: vector::empty(),
            };
            let id = object::id(&addressesSubObj);
            vector::append(&mut addressesSubObj.addresses, addresses);
            object_table::add(&mut addressesObj.addressesSubObjs_table, id, addressesSubObj);
            vector::push_back(&mut addressesObj.addressesSubObjs_keys, id);
        }else{
            vector::append(&mut latestSubObj.addresses, addresses);
        }
    }
    public entry fun finalize<T>(
        addressesObj: &mut AddressesObj<T>,
        fee: u64,
        ctx: &mut TxContext
    ){
        addressesObj.fee = fee;
    }
    public (friend) fun clear<T>(
        addressesObj: &mut AddressesObj<T>,
    ){
        let index = 0;
        while (index < vector::length(&addressesObj.addressesSubObjs_keys)) {
            let id = vector::borrow(&addressesObj.addressesSubObjs_keys, index);
            let addressesSubObj = object_table::remove(&mut addressesObj.addressesSubObjs_table, *id);
            addressesSubObj.addresses = vector::empty();
            destroy_AddressesSubObj(addressesSubObj);
            index = index + 1;
        };
        addressesObj.addressesSubObjs_keys = vector::empty();
    }
    fun destroy_AddressesSubObj(addressesSubObj:  AddressesSubObj){
        let AddressesSubObj { id, addresses } = addressesSubObj;
        object::delete(id)
    }
    public entry fun clearByCreator<T>(
        addressesObj: &mut AddressesObj<T>,
        ctx: &mut TxContext
    ){
        assert!(addressesObj.creator == tx_context::sender(ctx),1);
        clear(addressesObj);
    }
    

    public fun getAddresses<T>(
        addressesObj: &AddressesObj<T>,
    ): vector<address> {
        let index = 0;
        let all_addresses = vector::empty<address>();
        while (index < vector::length(&addressesObj.addressesSubObjs_keys)) {
            let id = vector::borrow(&addressesObj.addressesSubObjs_keys, index);
            let addressesSubObj = object_table::borrow(&addressesObj.addressesSubObjs_table, *id);
            let subIndex = 0;
            while (subIndex < vector::length(&addressesSubObj.addresses)) {
                let address = vector::borrow(&addressesSubObj.addresses, subIndex);
                vector::push_back(&mut all_addresses, *address);
                subIndex = subIndex + 1;
            };
            index = index + 1;
        };
        return all_addresses
    }
    public fun getCreator<T>(
        addressesObj: &AddressesObj<T>,
    ): address {
        return addressesObj.creator
    }
    public fun getFee<T>(
        addressesObj: &AddressesObj<T>,
    ): u64 {
        return addressesObj.fee
    }

    #[test]
    fun test() {
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
        
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        
        {
            let participants = vector::empty<address>();
            vector::push_back(&mut participants, user1);
            vector::push_back(&mut participants, user2);
            vector::push_back(&mut participants, user3);
            vector::push_back(&mut participants, user4);
            vector::push_back(&mut participants, user5);
            vector::push_back(&mut participants, user6);
            vector::push_back(&mut participants, user7);
            create<TEST_COIN>(participants, test_scenario::ctx(scenario));
        };
        
        let i = 0;
        while(i < 100){
            test_scenario::next_tx(scenario, admin);
            {
                let addressesObj = test_scenario::take_from_address<AddressesObj<TEST_COIN>>(scenario, admin);
                let participants = vector::empty<address>();
                vector::push_back(&mut participants, user1);
                vector::push_back(&mut participants, user2);
                vector::push_back(&mut participants, user3);
                vector::push_back(&mut participants, user4);
                vector::push_back(&mut participants, user5);
                vector::push_back(&mut participants, user6);
                vector::push_back(&mut participants, user7);
                add_addresses(&mut addressesObj, participants, test_scenario::ctx(scenario));
                test_scenario::return_to_address(admin, addressesObj);
            };
            i = i+1;
        };
        test_scenario::next_tx(scenario, admin);
        let fee = 50000;
        {
            let addressesObj = test_scenario::take_from_address<AddressesObj<TEST_COIN>>(scenario, admin);
            finalize(&mut addressesObj, fee, test_scenario::ctx(scenario));
            transfer::public_transfer(addressesObj, host);
        };

        test_scenario::next_tx(scenario, host);
        {
            let addressesObj = test_scenario::take_from_address<AddressesObj<TEST_COIN>>(scenario, host);
            clear(&mut addressesObj);
            assert!(vector::length(&addressesObj.addressesSubObjs_keys) == 0, 0);
            test_scenario::return_to_address(host, addressesObj);
        };
        test_scenario::end(scenario_val);
    }
}
