use starknet::ContractAddress;

#[derive(Drop, Serde, Clone, starknet::Store)]
pub struct GiftMetadata {
    pub token_id: u256,
    pub category: GiftCategory,
    pub rarity: Rarity,
    pub celebrity_id: u256,
    pub token_uri: ByteArray,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Celebrity {
    pub id: u256,
    pub address: ContractAddress,
    pub celebrityname: felt252,
    pub verified: bool,
    pub royaltyPercentage: u256,
    pub registered: bool,
    pub manager: ContractAddress,
    pub preferences: GiftCategory,
}

#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum Rarity {
    #[default]
    Common,
    Rare,
    Legendary,
    Exclusive,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum GiftCategory {
    #[default]
    NoneSet,
    Roses,
    Shoutout,
    Collectible,
    Custom,
}


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
