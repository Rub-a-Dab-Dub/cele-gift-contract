use debug::PrintTrait;
use array::ArrayTrait;
use result::ResultTrait;
use traits::TryInto;
use option::OptionTrait;
use traits::Into;
use box::BoxTrait;
use starknet::ContractAddress;
use starknet::ContractAddressIntoFelt252;
use starknet::Felt252TryIntoContractAddress;
use starknet::get_block_timestamp;
use starknet::testing::{set_caller_address, set_contract_address, start_prank, stop_prank};

use cele_gift_contract::contracts::cgift_token::ICGIFTTokenDispatcher;
use cele_gift_contract::contracts::cgift_token::ICGIFTTokenDispatcherTrait;

fn deploy_cgift_token() -> ICGIFTTokenDispatcher {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let initial_supply: u256 = 1000000 * 10u256.pow(18); // 1 million tokens
    let mut calldata = ArrayTrait::new();
    calldata.append(owner.into());
    calldata.append(initial_supply.into());
    let contract_address = deploy_contract('cgift_token', @calldata);
    ICGIFTTokenDispatcher { contract_address }
}

#[test]
fn test_erc20_functions() {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let cgift = deploy_cgift_token();
    
    // Test name and symbol
    let name = cgift.name();
    let symbol = cgift.symbol();
    assert(name == 'CeleGift Token', 'Wrong name');
    assert(symbol == 'CGIFT', 'Wrong symbol');
    
    // Test decimals
    let decimals = cgift.decimals();
    assert(decimals == 18, 'Wrong decimals');
    
    // Test initial supply
    let total_supply = cgift.total_supply();
    assert(total_supply == 1000000 * 10u256.pow(18), 'Wrong total supply');
    
    // Test balance of owner
    let balance = cgift.balance_of(owner);
    assert(balance == total_supply, 'Wrong owner balance');
    
    // Test transfer
    let transfer_amount: u256 = 1000 * 10u256.pow(18);
    set_caller_address(owner);
    cgift.transfer(user, transfer_amount);
    
    let user_balance = cgift.balance_of(user);
    assert(user_balance == transfer_amount, 'Wrong user balance after transfer');
    
    // Test approve and transferFrom
    let spender: ContractAddress = starknet::contract_address_const::<0x789>();
    let approve_amount: u256 = 500 * 10u256.pow(18);
    
    set_caller_address(user);
    cgift.approve(spender, approve_amount);
    
    let allowance = cgift.allowance(user, spender);
    assert(allowance == approve_amount, 'Wrong allowance');
    
    set_caller_address(spender);
    cgift.transfer_from(user, spender, approve_amount);
    
    let spender_balance = cgift.balance_of(spender);
    assert(spender_balance == approve_amount, 'Wrong spender balance after transferFrom');
}

#[test]
fn test_staking() {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let cgift = deploy_cgift_token();
    
    // Transfer tokens to user
    let stake_amount: u256 = 2000 * 10u256.pow(18);
    set_caller_address(owner);
    cgift.transfer(user, stake_amount);
    
    // Test staking
    set_caller_address(user);
    cgift.approve(cgift.contract_address, stake_amount);
    cgift.stake(stake_amount);
    
    let staked_balance = cgift.get_staked_balance(user);
    assert(staked_balance == stake_amount, 'Wrong staked balance');
    
    // Test unstaking
    let unstake_amount: u256 = 1000 * 10u256.pow(18);
    cgift.unstake(unstake_amount);
    
    let new_staked_balance = cgift.get_staked_balance(user);
    assert(new_staked_balance == stake_amount - unstake_amount, 'Wrong staked balance after unstake');
    
    // Test minimum stake amount
    let small_amount: u256 = 500 * 10u256.pow(18);
    let mut success = false;
    match cgift.try_stake(small_amount) {
        Ok(_) => {},
        Err(_) => { success = true; }
    }
    assert(success, 'Should fail for amount below minimum stake');
}

#[test]
fn test_governance() {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let cgift = deploy_cgift_token();
    
    // Transfer tokens to user for voting power
    let voting_amount: u256 = 15000 * 10u256.pow(18);
    set_caller_address(owner);
    cgift.transfer(user, voting_amount);
    
    // Test proposal creation
    set_caller_address(user);
    cgift.approve(cgift.contract_address, voting_amount);
    cgift.stake(voting_amount);
    
    let proposal_id = cgift.create_proposal('Test Proposal', 3 * 24 * 60 * 60);
    let proposal = cgift.get_proposal(proposal_id);
    
    assert(proposal.proposer == user, 'Wrong proposer');
    assert(proposal.description == 'Test Proposal', 'Wrong proposal description');
    
    // Test voting
    cgift.vote(proposal_id, true);
    let voting_power = cgift.get_voting_power(user);
    assert(voting_power == voting_amount, 'Wrong voting power');
    
    // Test proposal execution
    // Note: In a real test, we would need to advance time to test execution
    let mut success = false;
    match cgift.try_execute_proposal(proposal_id) {
        Ok(_) => {},
        Err(_) => { success = true; }
    }
    assert(success, 'Should fail to execute before voting period ends');
}

#[test]
fn test_token_burn() {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let cgift = deploy_cgift_token();
    
    // Transfer tokens to user
    let burn_amount: u256 = 1000 * 10u256.pow(18);
    set_caller_address(owner);
    cgift.transfer(user, burn_amount);
    
    // Test burn
    set_caller_address(user);
    let initial_supply = cgift.total_supply();
    cgift.burn(burn_amount);
    
    let new_supply = cgift.total_supply();
    assert(new_supply == initial_supply - burn_amount, 'Wrong supply after burn');
    
    // Test burnFrom
    let burn_from_amount: u256 = 500 * 10u256.pow(18);
    set_caller_address(owner);
    cgift.transfer(user, burn_from_amount);
    
    set_caller_address(user);
    cgift.approve(owner, burn_from_amount);
    
    set_caller_address(owner);
    cgift.burn_from(user, burn_from_amount);
    
    let final_supply = cgift.total_supply();
    assert(final_supply == new_supply - burn_from_amount, 'Wrong supply after burnFrom');
}

#[test]
fn test_liquidity_mining() {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let pool: ContractAddress = starknet::contract_address_const::<0x789>();
    let cgift = deploy_cgift_token();
    
    // Add liquidity pool
    set_caller_address(owner);
    let reward_rate: u256 = 200; // 2% per year
    cgift.add_liquidity_pool(pool, reward_rate);
    
    // Transfer tokens to user
    let liquidity_amount: u256 = 5000 * 10u256.pow(18);
    cgift.transfer(user, liquidity_amount);
    
    // Test liquidity deposit
    set_caller_address(user);
    cgift.approve(cgift.contract_address, liquidity_amount);
    cgift.deposit_liquidity(pool, liquidity_amount);
    
    // Test liquidity withdrawal
    let withdraw_amount: u256 = 2000 * 10u256.pow(18);
    cgift.withdraw_liquidity(pool, withdraw_amount);
    
    // Test reward claiming
    // Note: In a real test, we would need to advance time to test rewards
    let mut success = false;
    match cgift.try_claim_liquidity_rewards(pool) {
        Ok(_) => {},
        Err(_) => { success = true; }
    }
    assert(success, 'Should fail to claim rewards immediately');
}

#[test]
fn test_pausable() {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let cgift = deploy_cgift_token();
    
    // Transfer tokens to user
    let amount: u256 = 1000 * 10u256.pow(18);
    set_caller_address(owner);
    cgift.transfer(user, amount);
    
    // Pause contract
    cgift.pause();
    
    // Test that transfers are blocked
    set_caller_address(user);
    let mut success = false;
    match cgift.try_transfer(owner, amount) {
        Ok(_) => {},
        Err(_) => { success = true; }
    }
    assert(success, 'Should fail to transfer when paused');
    
    // Unpause contract
    set_caller_address(owner);
    cgift.unpause();
    
    // Test that transfers work again
    set_caller_address(user);
    cgift.transfer(owner, amount);
    
    let balance = cgift.balance_of(owner);
    assert(balance == cgift.total_supply(), 'Transfer should work after unpause');
} 
