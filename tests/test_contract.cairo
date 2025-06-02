use cele_gift_contract::base::types::{Celebrity, GiftCategory, GiftMetadata, Rarity};
use cele_gift_contract::interfaces::IRubDubNFT::{IRubDubNFTDispatcher, IRubDubNFTDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address, contract_address_const, get_block_timestamp};


fn setup() -> ContractAddress {
    let declare_result = declare("RubDub");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    contract_address
}

#[test]
fn test_register_celebrity() {
    let contract_address = setup();
    let dispatcher = IRubDubNFTDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let user_name = 'wizkid';

    // Ensure the caller is the admin
    start_cheat_caller_address(contract_address, user);
    // Call create_job
    let celebrity_id = dispatcher.register_celebrity(user, user_name);

    // Validate that the coujobrse ID is correctly incremented
    assert(celebrity_id == 1, 'job_id should start from 1');

    let celebrity = dispatcher.get_celebrity(celebrity_id);

    assert(celebrity.address == user, ' user address mismatch');
    assert(celebrity.celebrityname == user_name, 'username mismatch');
    assert(celebrity.registered, 'registration failed');
    assert(celebrity.royaltyPercentage == 10, 'royalty mismatch');
}

#[test]
fn test_mint_gift() {
    let contract_address = setup();
    let dispatcher = IRubDubNFTDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let user_name = 'wizkid';
    let token_uri = "ipfs/x";

    // Ensure the caller is the admin
    start_cheat_caller_address(contract_address, user);
    // Call create_job
    let celebrity_id = dispatcher.register_celebrity(user, user_name);

    // Validate that the coujobrse ID is correctly incremented
    assert(celebrity_id == 1, 'job_id should start from 1');

    let celebrity = dispatcher.get_celebrity(celebrity_id);

    dispatcher.mint_gift(user, GiftCategory::Roses, Rarity::Rare, celebrity.id, token_uri);

    let onwer_of = dispatcher.owner(1);
    assert(onwer_of == user, 'mint fail');
}

#[test]
fn test_batch_mint_gift() {
    let contract_address = setup();
    let dispatcher = IRubDubNFTDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let user_name = 'wizkid';
    let token_uri = "ipfs/x";

    // Ensure the caller is the admin
    start_cheat_caller_address(contract_address, user);
    // Call create_job
    let celebrity_id = dispatcher.register_celebrity(user, user_name);

    // Validate that the coujobrse ID is correctly incremented
    assert(celebrity_id == 1, 'job_id should start from 1');

    let celebrity = dispatcher.get_celebrity(celebrity_id);

    dispatcher
        .batch_mint_gifts(user, 10, GiftCategory::Roses, Rarity::Rare, celebrity.id, token_uri);

    let onwer_of = dispatcher.owner(8);
    assert(onwer_of == user, 'mint fail');
}
// #[test]
// #[should_panic(expected: ('Not the content creator',))]

// println!("Array len: {}", job.len());


