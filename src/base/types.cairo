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
