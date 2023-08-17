// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::addresses_hash_proof {
    friend raffle::nft_raffle;
    friend raffle::raffle;
    friend raffle::addresses_obj;
    use sui::object::{Self, ID, UID};
    use std::vector;
    use sui::tx_context::{Self, TxContext};
    use sui::object_table::{Self, ObjectTable};
    use std::bcs;
    use std::hash::{Self};

    public fun hash_addresses(addresses: vector<address>): vector<u8> {
        let all_bytes = vector::empty<u8>();
        let index = 0;
        let len = vector::length(&addresses);
        while(index < len) {
            let byte = bcs::to_bytes(vector::borrow(&addresses, index));
            vector::append(&mut all_bytes, byte);
            index = index + 1
        };
        return hash::sha3_256(all_bytes)
    }

    #[test]
    fun test() {
        use raffle::test_coin::{Self, TEST_COIN};
        use sui::test_scenario;
        use sui::balance;
        use std::debug;

        // create test addresses representing users
        let user: address = @0x96d9a120058197fce04afcffa264f2f46747881ba78a91beb38f103c60e315ae;
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, user);
        vector::push_back(&mut addresses, user);
        vector::push_back(&mut addresses, user);
        let hash = hash_addresses(addresses);
        assert!(hash == x"6ac15cfb5b577f6ed7b38e6a5ee24c1e37f0d94115e088ea31d88c69e664ac8b", 0);
    }
}