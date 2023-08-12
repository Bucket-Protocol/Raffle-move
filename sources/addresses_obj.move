// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::addresses_obj {
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

    struct AddressesObj<phantom T> has key, store {
        id: UID,
        addresses: vector<address>,
        creator: address,
        fee: u64,
    }

    public entry fun create<T>(
        participants: vector<address>, 
        ctx: &mut TxContext
    ){
        let addressesObj = AddressesObj<T> {
            id: object::new(ctx),
            addresses: participants,
            creator: tx_context::sender(ctx),
            fee:0,
        };
        transfer::transfer(addressesObj, tx_context::sender(ctx));
    }
    public entry fun add_addresses<T>(
        addressesObj: &mut AddressesObj<T>,
        addresses: vector<address>, 
        ctx: &mut TxContext
    ){
        vector::append(&mut addressesObj.addresses, addresses);
    }
    public entry fun finalize<T>(
        addressesObj: &mut AddressesObj<T>,
        fee: u64,
        ctx: &mut TxContext
    ){
        addressesObj.fee = fee;
    }
    public entry fun clear<T>(
        addressesObj: &mut AddressesObj<T>,
        ctx: &mut TxContext
    ){
        assert!(addressesObj.creator == tx_context::sender(ctx),1);
        addressesObj.addresses = vector::empty();
    }
    public fun getParticipants<T>(
        addressesObj: &AddressesObj<T>,
    ): vector<address> {
        return addressesObj.addresses
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
    public fun update_adresses_and_return_old<T>(
        addressesObj: &mut AddressesObj<T>,
        new_addresses: vector<address>, 
    ): vector<address>{
        let old_addresses = addressesObj.addresses;
        addressesObj.addresses = new_addresses;
        return old_addresses
    }
}
