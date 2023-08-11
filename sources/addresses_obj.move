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

    struct AddressesObj has key, store {
        id: UID,
        addresses: vector<address>,
        creator: address,
        fee: u64,
    }

    public entry fun create_addresses_obj(
        participants: vector<address>, 
        ctx: &mut TxContext
    ){
        let addressesObj = AddressesObj {
            id: object::new(ctx),
            addresses: participants,
            creator: tx_context::sender(ctx),
            fee:0,
        };
        transfer::transfer(addressesObj, tx_context::sender(ctx));
    }
    public entry fun add_addresses(
        addressesObj: &mut AddressesObj,
        participants: vector<address>, 
        ctx: &mut TxContext
    ){
        vector::append(&mut addressesObj.addresses, participants);
    }
    public entry fun finalize(
        addressesObj: &mut AddressesObj,
        fee: u64,
        ctx: &mut TxContext
    ){
        addressesObj.fee = fee;
    }
    public fun getParticipants(
        addressesObj: &AddressesObj,
    ): vector<address> {
        return addressesObj.addresses
    }
    public fun getCreator(
        addressesObj: &AddressesObj,
    ): address {
        return addressesObj.creator
    }
    public fun getFee(
        addressesObj: &AddressesObj,
    ): u64 {
        return addressesObj.fee
    }
    public fun update_adresses_and_return_old(
        addressesObj: &mut AddressesObj,
        new_addresses: vector<address>, 
    ): vector<address>{
        let old_addresses = addressesObj.addresses;
        addressesObj.addresses = new_addresses;
        return old_addresses
    }
}
