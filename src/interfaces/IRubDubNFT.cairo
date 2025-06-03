use cele_gift_contract::base::types::{Celebrity, GiftCategory, GiftMetadata, Rarity};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IRubDubNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
    fn is_owner(ref self: TContractState, token_id: u256) -> ContractAddress;
    fn get_symbol(self: @TContractState) -> ByteArray;
    fn get_name(self: @TContractState) -> ByteArray;
    fn register_celebrity(
        ref self: TContractState, address: ContractAddress, celebrityname: felt252,
    ) -> u256;
    fn get_celebrity(self: @TContractState, celebrity_id: u256) -> Celebrity;
    fn mint_gift(
        ref self: TContractState,
        recipient: ContractAddress,
        category: GiftCategory,
        rarity: Rarity,
        celebrity_id: u256,
        token_uri: ByteArray,
    );

    fn get_manager(self: @TContractState, celebrity_id: u256) -> ContractAddress ;

    fn batch_mint_gifts(
        ref self: TContractState,
        recipient: ContractAddress,
        count: u32,
        category: GiftCategory,
        rarity: Rarity,
        celebrity_id: u256,
        token_uri: ByteArray,
    );

    fn gift_token(
        ref self: TContractState, token: ContractAddress, receiver: ContractAddress, amount: u256,
    ) -> bool;

    fn delegate_manager(
        ref self: TContractState,
        celebrity_address: ContractAddress,
        manager: ContractAddress,
    ) ;

    fn set_gift_preferences(
        ref self: TContractState,
        celebrity_address: ContractAddress,
        preferences: GiftCategory,
    );

    fn get_preferences(self: @TContractState, celebrity_id: u256) -> GiftCategory;

    fn verify_celebrity(ref self: TContractState, address: ContractAddress);
    fn get_metadata(self: @TContractState, token_id: u256) -> GiftMetadata;
    fn owner(self: @TContractState, token_id: u256) -> ContractAddress;
}
