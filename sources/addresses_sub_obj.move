// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Example of objects that can be combined to create
/// new objects
module raffle::addresses_sub_obj {
    friend raffle::nft_raffle;
    friend raffle::raffle;
    friend raffle::addresses_obj;
    use sui::object::{Self, ID, UID};
    use std::vector;
    use sui::tx_context::{Self, TxContext};


    struct AddressesSubObj has key, store {
        id: UID,
        addresses: vector<address>,
    }


    public (friend) fun create(
        addresses: vector<address>,
        ctx: &mut TxContext
    ): AddressesSubObj{
        return AddressesSubObj {
            id: object::new(ctx),
            addresses: addresses,
        }
    }
    public (friend) fun append(
        addressesSubObj: &mut AddressesSubObj,
        addresses: vector<address>,
    ){
        vector::append(&mut addressesSubObj.addresses,addresses);
    }

    public (friend) fun size(
        addressesSubObj: &AddressesSubObj,
    ):u64{
        vector::length(&addressesSubObj.addresses)
    }

    public (friend) fun get_addresses(
        addressesSubObj: &AddressesSubObj,
        
    ):&vector<address>{
        &addressesSubObj.addresses
    }
    public (friend) fun get_addresses_mut(
        addressesSubObj: &mut AddressesSubObj,
    ):&mut vector<address>{
        &mut addressesSubObj.addresses
    }

    public (friend) fun destroy(addressesSubObj:  AddressesSubObj){
        let AddressesSubObj { id, addresses } = addressesSubObj;
        object::delete(id)
    }
}
