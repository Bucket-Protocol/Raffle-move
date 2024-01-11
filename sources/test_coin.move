#[test_only]
module raffle::test_coin {
    use sui::coin::{Self};
    use std::option::{Self};
    use sui::transfer;    
    use sui::tx_context::{Self, TxContext};
    
    struct TEST_COIN has drop {}
    
    fun init(otw: TEST_COIN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            otw, 
            2, 
            b"MANAGED", 
            b"MANAGED", 
            b"", 
            option::none(), 
            ctx
        );
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }
}
