#[starknet::interface]
pub trait ICGIFTToken<TContractState> {
    // Core ERC20 functions
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    // Staking functions
    fn stake(ref self: TContractState, amount: u256);
    fn unstake(ref self: TContractState, amount: u256);
    fn claim_rewards(ref self: TContractState);
    fn get_staked_balance(self: @TContractState, account: ContractAddress) -> u256;
    fn get_rewards(self: @TContractState, account: ContractAddress) -> u256;

    // Governance functions
    fn create_proposal(ref self: TContractState, description: ByteArray, duration: u64) -> u256;
    fn vote(ref self: TContractState, proposal_id: u256, support: bool);
    fn execute_proposal(ref self: TContractState, proposal_id: u256);
    fn get_proposal(self: @TContractState, proposal_id: u256) -> Proposal;
    fn get_voting_power(self: @TContractState, account: ContractAddress) -> u256;

    // Token burn functions
    fn burn(ref self: TContractState, amount: u256);
    fn burn_from(ref self: TContractState, account: ContractAddress, amount: u256);

    // Liquidity mining functions
    fn add_liquidity_pool(ref self: TContractState, pool_address: ContractAddress, reward_rate: u256);
    fn remove_liquidity_pool(ref self: TContractState, pool_address: ContractAddress);
    fn deposit_liquidity(ref self: TContractState, pool_address: ContractAddress, amount: u256);
    fn withdraw_liquidity(ref self: TContractState, pool_address: ContractAddress, amount: u256);
    fn claim_liquidity_rewards(ref self: TContractState, pool_address: ContractAddress);
}

#[derive(Drop, starknet::Store, Serde)]
struct Proposal {
    id: u256,
    proposer: ContractAddress,
    description: ByteArray,
    start_time: u64,
    end_time: u64,
    for_votes: u256,
    against_votes: u256,
    executed: bool,
    canceled: bool
}

#[derive(Drop, starknet::Store, Serde)]
struct StakingInfo {
    amount: u256,
    last_update_time: u64,
    rewards_claimed: u256
}

#[derive(Drop, starknet::Store, Serde)]
struct LiquidityPool {
    reward_rate: u256,
    total_liquidity: u256,
    last_update_time: u64,
    reward_per_token_stored: u256
}

#[derive(Drop, starknet::Store, Serde)]
struct UserLiquidityInfo {
    amount: u256,
    reward_debt: u256
}

#[starknet::contract]
pub mod CGIFTToken {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    const REWARD_RATE: u256 = 100; // 1% per year
    const MIN_STAKE_AMOUNT: u256 = 1000; // Minimum stake amount
    const MIN_PROPOSAL_THRESHOLD: u256 = 10000; // Minimum tokens needed to create proposal
    const VOTING_PERIOD: u64 = 3 * 24 * 60 * 60; // 3 days in seconds

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,

        // Staking
        staking_info: LegacyMap::<ContractAddress, StakingInfo>,
        total_staked: u256,
        reward_per_token_stored: u256,
        last_update_time: u64,

        // Governance
        proposals: LegacyMap::<u256, Proposal>,
        proposal_count: u256,
        votes: LegacyMap::<(u256, ContractAddress), bool>,
        voting_power: LegacyMap::<ContractAddress, u256>,

        // Liquidity mining
        liquidity_pools: LegacyMap::<ContractAddress, LiquidityPool>,
        user_liquidity: LegacyMap::<(ContractAddress, ContractAddress), UserLiquidityInfo>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        Staked: Staked,
        Unstaked: Unstaked,
        RewardsClaimed: RewardsClaimed,
        ProposalCreated: ProposalCreated,
        Voted: Voted,
        ProposalExecuted: ProposalExecuted,
        TokensBurned: TokensBurned,
        LiquidityPoolAdded: LiquidityPoolAdded,
        LiquidityDeposited: LiquidityDeposited,
        LiquidityWithdrawn: LiquidityWithdrawn,
        LiquidityRewardsClaimed: LiquidityRewardsClaimed,
    }

    #[derive(Drop, starknet::Event)]
    struct Staked {
        account: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Unstaked {
        account: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RewardsClaimed {
        account: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        proposal_id: u256,
        proposer: ContractAddress,
        description: ByteArray
    }

    #[derive(Drop, starknet::Event)]
    struct Voted {
        proposal_id: u256,
        voter: ContractAddress,
        support: bool
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalExecuted {
        proposal_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct TokensBurned {
        account: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityPoolAdded {
        pool_address: ContractAddress,
        reward_rate: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityDeposited {
        pool_address: ContractAddress,
        account: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityWithdrawn {
        pool_address: ContractAddress,
        account: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityRewardsClaimed {
        pool_address: ContractAddress,
        account: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        initial_supply: u256
    ) {
        self.erc20.initializer(
            format!("CeleGift Token"),
            format!("CGIFT"),
            18
        );
        self.ownable.initializer(owner);
        self.pausable.initializer();

        // Mint initial supply to owner
        self.erc20.mint(owner, initial_supply);
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn update_rewards(ref self: ContractState, account: ContractAddress) {
            let current_time = get_block_timestamp();
            let total_staked = self.total_staked.read();
            
            if total_staked > 0 {
                let time_diff = current_time - self.last_update_time.read();
                let reward = (time_diff * REWARD_RATE * total_staked) / (365 * 24 * 60 * 60 * 10000);
                self.reward_per_token_stored.write(
                    self.reward_per_token_stored.read() + (reward * 1e18) / total_staked
                );
            }
            
            self.last_update_time.write(current_time);
            
            if account != starknet::contract_address_const::<0>() {
                let mut staking_info = self.staking_info.read(account);
                staking_info.rewards_claimed = self._calculate_rewards(account);
                staking_info.last_update_time = current_time;
                self.staking_info.write(account, staking_info);
            }
        }

        fn _calculate_rewards(self: @ContractState, account: ContractAddress) -> u256 {
            let staking_info = self.staking_info.read(account);
            let reward_per_token = self.reward_per_token_stored.read();
            let pending_rewards = (staking_info.amount * (reward_per_token - staking_info.rewards_claimed)) / 1e18;
            pending_rewards
        }

        fn _update_voting_power(ref self: ContractState, account: ContractAddress) {
            let staked_amount = self.get_staked_balance(@self, account);
            self.voting_power.write(account, staked_amount);
        }
    }

    // External implementations
    #[abi(embed_v0)]
    impl CGIFTTokenImpl of super::ICGIFTToken<ContractState> {
        // ERC20 functions
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();
            self.erc20.transfer(recipient, amount)
        }

        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();
            self.erc20.transfer_from(sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();
            self.erc20.approve(spender, amount)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        // Staking functions
        fn stake(ref self: ContractState, amount: u256) {
            self.pausable.assert_not_paused();
            assert(amount >= MIN_STAKE_AMOUNT, 'Amount below minimum stake');
            
            let caller = get_caller_address();
            InternalFunctions::update_rewards(ref self, caller);
            
            self.erc20.transfer_from(caller, get_contract_address(), amount);
            
            let mut staking_info = self.staking_info.read(caller);
            staking_info.amount += amount;
            self.staking_info.write(caller, staking_info);
            
            self.total_staked.write(self.total_staked.read() + amount);
            InternalFunctions::_update_voting_power(ref self, caller);
            
            self.emit(Staked { account: caller, amount });
        }

        fn unstake(ref self: ContractState, amount: u256) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            InternalFunctions::update_rewards(ref self, caller);
            
            let mut staking_info = self.staking_info.read(caller);
            assert(staking_info.amount >= amount, 'Insufficient staked amount');
            
            staking_info.amount -= amount;
            self.staking_info.write(caller, staking_info);
            
            self.total_staked.write(self.total_staked.read() - amount);
            InternalFunctions::_update_voting_power(ref self, caller);
            
            self.erc20.transfer(caller, amount);
            
            self.emit(Unstaked { account: caller, amount });
        }

        fn claim_rewards(ref self: ContractState) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            InternalFunctions::update_rewards(ref self, caller);
            
            let rewards = InternalFunctions::_calculate_rewards(@self, caller);
            assert(rewards > 0, 'No rewards to claim');
            
            let mut staking_info = self.staking_info.read(caller);
            staking_info.rewards_claimed = self.reward_per_token_stored.read();
            self.staking_info.write(caller, staking_info);
            
            self.erc20.mint(caller, rewards);
            
            self.emit(RewardsClaimed { account: caller, amount: rewards });
        }

        fn get_staked_balance(self: @ContractState, account: ContractAddress) -> u256 {
            self.staking_info.read(account).amount
        }

        fn get_rewards(self: @ContractState, account: ContractAddress) -> u256 {
            InternalFunctions::_calculate_rewards(@self, account)
        }

        // Governance functions
        fn create_proposal(ref self: ContractState, description: ByteArray, duration: u64) -> u256 {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            let voting_power = self.voting_power.read(caller);
            assert(voting_power >= MIN_PROPOSAL_THRESHOLD, 'Insufficient voting power');
            
            let proposal_id = self.proposal_count.read() + 1;
            let current_time = get_block_timestamp();
            
            let proposal = Proposal {
                id: proposal_id,
                proposer: caller,
                description,
                start_time: current_time,
                end_time: current_time + duration,
                for_votes: 0,
                against_votes: 0,
                executed: false,
                canceled: false
            };
            
            self.proposals.write(proposal_id, proposal);
            self.proposal_count.write(proposal_id);
            
            self.emit(ProposalCreated { proposal_id, proposer: caller, description });
            
            proposal_id
        }

        fn vote(ref self: ContractState, proposal_id: u256, support: bool) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            let voting_power = self.voting_power.read(caller);
            assert(voting_power > 0, 'No voting power');
            
            let mut proposal = self.proposals.read(proposal_id);
            let current_time = get_block_timestamp();
            
            assert(current_time >= proposal.start_time, 'Voting not started');
            assert(current_time <= proposal.end_time, 'Voting ended');
            assert(!proposal.executed, 'Proposal already executed');
            assert(!proposal.canceled, 'Proposal canceled');
            
            // Remove previous vote if exists
            let previous_vote = self.votes.read((proposal_id, caller));
            if previous_vote {
                if previous_vote {
                    proposal.for_votes -= voting_power;
                } else {
                    proposal.against_votes -= voting_power;
                }
            }
            
            // Add new vote
            if support {
                proposal.for_votes += voting_power;
            } else {
                proposal.against_votes += voting_power;
            }
            
            self.proposals.write(proposal_id, proposal);
            self.votes.write((proposal_id, caller), support);
            
            self.emit(Voted { proposal_id, voter: caller, support });
        }

        fn execute_proposal(ref self: ContractState, proposal_id: u256) {
            self.pausable.assert_not_paused();
            
            let mut proposal = self.proposals.read(proposal_id);
            let current_time = get_block_timestamp();
            
            assert(current_time > proposal.end_time, 'Voting still active');
            assert(!proposal.executed, 'Proposal already executed');
            assert(!proposal.canceled, 'Proposal canceled');
            assert(proposal.for_votes > proposal.against_votes, 'Proposal not passed');
            
            proposal.executed = true;
            self.proposals.write(proposal_id, proposal);
            
            self.emit(ProposalExecuted { proposal_id });
        }

        fn get_proposal(self: @ContractState, proposal_id: u256) -> Proposal {
            self.proposals.read(proposal_id)
        }

        fn get_voting_power(self: @ContractState, account: ContractAddress) -> u256 {
            self.voting_power.read(account)
        }

        // Token burn functions
        fn burn(ref self: ContractState, amount: u256) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            self.erc20.burn_from(caller, amount);
            
            self.emit(TokensBurned { account: caller, amount });
        }

        fn burn_from(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.pausable.assert_not_paused();
            
            self.erc20.burn_from(account, amount);
            
            self.emit(TokensBurned { account, amount });
        }

        // Liquidity mining functions
        fn add_liquidity_pool(ref self: ContractState, pool_address: ContractAddress, reward_rate: u256) {
            self.ownable.assert_only_owner();
            
            let pool = LiquidityPool {
                reward_rate,
                total_liquidity: 0,
                last_update_time: get_block_timestamp(),
                reward_per_token_stored: 0
            };
            
            self.liquidity_pools.write(pool_address, pool);
            
            self.emit(LiquidityPoolAdded { pool_address, reward_rate });
        }

        fn remove_liquidity_pool(ref self: ContractState, pool_address: ContractAddress) {
            self.ownable.assert_only_owner();
            
            let pool = self.liquidity_pools.read(pool_address);
            assert(pool.total_liquidity == 0, 'Pool has active liquidity');
            
            self.liquidity_pools.write(pool_address, LiquidityPool {
                reward_rate: 0,
                total_liquidity: 0,
                last_update_time: 0,
                reward_per_token_stored: 0
            });
        }

        fn deposit_liquidity(ref self: ContractState, pool_address: ContractAddress, amount: u256) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            let mut pool = self.liquidity_pools.read(pool_address);
            let mut user_info = self.user_liquidity.read((pool_address, caller));
            
            // Update rewards
            if pool.total_liquidity > 0 {
                let time_diff = get_block_timestamp() - pool.last_update_time;
                let reward = (time_diff * pool.reward_rate * pool.total_liquidity) / (365 * 24 * 60 * 60 * 10000);
                pool.reward_per_token_stored += (reward * 1e18) / pool.total_liquidity;
            }
            
            // Update user rewards
            if user_info.amount > 0 {
                let pending_rewards = (user_info.amount * (pool.reward_per_token_stored - user_info.reward_debt)) / 1e18;
                if pending_rewards > 0 {
                    self.erc20.mint(caller, pending_rewards);
                }
            }
            
            // Update pool and user info
            pool.total_liquidity += amount;
            pool.last_update_time = get_block_timestamp();
            
            user_info.amount += amount;
            user_info.reward_debt = pool.reward_per_token_stored;
            
            self.liquidity_pools.write(pool_address, pool);
            self.user_liquidity.write((pool_address, caller), user_info);
            
            self.emit(LiquidityDeposited { pool_address, account: caller, amount });
        }

        fn withdraw_liquidity(ref self: ContractState, pool_address: ContractAddress, amount: u256) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            let mut pool = self.liquidity_pools.read(pool_address);
            let mut user_info = self.user_liquidity.read((pool_address, caller));
            
            assert(user_info.amount >= amount, 'Insufficient liquidity');
            
            // Update rewards
            if pool.total_liquidity > 0 {
                let time_diff = get_block_timestamp() - pool.last_update_time;
                let reward = (time_diff * pool.reward_rate * pool.total_liquidity) / (365 * 24 * 60 * 60 * 10000);
                pool.reward_per_token_stored += (reward * 1e18) / pool.total_liquidity;
            }
            
            // Update user rewards
            let pending_rewards = (user_info.amount * (pool.reward_per_token_stored - user_info.reward_debt)) / 1e18;
            if pending_rewards > 0 {
                self.erc20.mint(caller, pending_rewards);
            }
            
            // Update pool and user info
            pool.total_liquidity -= amount;
            pool.last_update_time = get_block_timestamp();
            
            user_info.amount -= amount;
            user_info.reward_debt = pool.reward_per_token_stored;
            
            self.liquidity_pools.write(pool_address, pool);
            self.user_liquidity.write((pool_address, caller), user_info);
            
            self.emit(LiquidityWithdrawn { pool_address, account: caller, amount });
        }

        fn claim_liquidity_rewards(ref self: ContractState, pool_address: ContractAddress) {
            self.pausable.assert_not_paused();
            
            let caller = get_caller_address();
            let pool = self.liquidity_pools.read(pool_address);
            let mut user_info = self.user_liquidity.read((pool_address, caller));
            
            let pending_rewards = (user_info.amount * (pool.reward_per_token_stored - user_info.reward_debt)) / 1e18;
            assert(pending_rewards > 0, 'No rewards to claim');
            
            user_info.reward_debt = pool.reward_per_token_stored;
            self.user_liquidity.write((pool_address, caller), user_info);
            
            self.erc20.mint(caller, pending_rewards);
            
            self.emit(LiquidityRewardsClaimed { pool_address, account: caller, amount: pending_rewards });
        }
    }

    // Implement required traits
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
} 