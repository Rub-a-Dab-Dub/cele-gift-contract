use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct AuctionData {
    seller: ContractAddress,
    nft_contract: ContractAddress,
    token_id: u256,
    start_price: u256,
    end_price: u256,
    reserve_price: u256,
    start_time: u64,
    end_time: u64,
    highest_bidder: ContractAddress,
    highest_bid: u256,
    auction_type: u8, // 0: Dutch, 1: English, 2: Reserve, 3: Sealed, 4: Batch
    is_active: bool,
    payment_token: ContractAddress,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct MarketplaceListing {
    seller: ContractAddress,
    nft_contract: ContractAddress,
    token_id: u256,
    price: u256,
    payment_token: ContractAddress,
    is_active: bool,
    created_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SealedBid {
    bidder: ContractAddress,
    bid_hash: felt252,
    revealed: bool,
    bid_amount: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct FractionalOwnership {
    nft_contract: ContractAddress,
    token_id: u256,
    total_shares: u256,
    price_per_share: u256,
    shares_sold: u256,
    is_active: bool,
}
