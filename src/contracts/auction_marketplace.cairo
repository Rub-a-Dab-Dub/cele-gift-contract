// Main Auction Marketplace Contract
// File: src/auction_marketplace.cairo

use starknet::ContractAddress;
pub mod interfaces;
use interfaces::*;
use crate::types::{AuctionData, MarketplaceListing, SealedBid, FractionalOwnership};

#[starknet::interface]
pub trait IGiftAuctionMarketplace<TContractState> {
    // Auction Functions
    fn create_dutch_auction(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        start_price: u256,
        end_price: u256,
        duration: u64,
        payment_token: ContractAddress
    ) -> u256;
    
    fn create_english_auction(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        starting_price: u256,
        reserve_price: u256,
        duration: u64,
        payment_token: ContractAddress
    ) -> u256;
    
    fn create_sealed_bid_auction(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        reserve_price: u256,
        bid_duration: u64,
        reveal_duration: u64,
        payment_token: ContractAddress
    ) -> u256;
    
    fn place_bid(ref self: TContractState, auction_id: u256, bid_amount: u256);
    fn place_sealed_bid(ref self: TContractState, auction_id: u256, bid_hash: felt252);
    fn reveal_sealed_bid(ref self: TContractState, auction_id: u256, bid_amount: u256, nonce: felt252);
    fn finalize_auction(ref self: TContractState, auction_id: u256);
    fn get_dutch_price(self: @TContractState, auction_id: u256) -> u256;
    
    // Marketplace Functions
    fn create_listing(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        price: u256,
        payment_token: ContractAddress
    ) -> u256;
    
    fn buy_now(ref self: TContractState, listing_id: u256);
    fn cancel_listing(ref self: TContractState, listing_id: u256);
    
    // Fractional Ownership
    fn create_fractional_ownership(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        total_shares: u256,
        price_per_share: u256
    ) -> u256;
    
    fn buy_shares(ref self: TContractState, fractional_id: u256, shares: u256);
    
    // Admin Functions
    fn set_marketplace_fee(ref self: TContractState, fee_percentage: u256);
    fn set_fee_recipient(ref self: TContractState, recipient: ContractAddress);
    fn pause_contract(ref self: TContractState);
    fn unpause_contract(ref self: TContractState);
    fn emergency_withdraw(ref self: TContractState, token: ContractAddress);
    
    // View Functions
    fn get_auction(self: @TContractState, auction_id: u256) -> AuctionData;
    fn get_listing(self: @TContractState, listing_id: u256) -> MarketplaceListing;
    fn get_fractional_ownership(self: @TContractState, fractional_id: u256) -> FractionalOwnership;
    fn is_paused(self: @TContractState) -> bool;
}

#[starknet::contract]
pub mod GiftAuctionMarketplace {
    use super::{AuctionData, MarketplaceListing, SealedBid, FractionalOwnership};
    use crate::interfaces::{IERC721Dispatcher, IERC721DispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait};
    use crate::utils::helpers::{compute_hash, calculate_dutch_price};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};

    #[storage]
    struct Storage {
        // Core state
        owner: ContractAddress,
        paused: bool,
        marketplace_fee: u256, // Basis points (e.g., 250 = 2.5%)
        fee_recipient: ContractAddress,
        
        // Auction storage
        auctions: LegacyMap<u256, AuctionData>,
        auction_counter: u256,
        sealed_bids: LegacyMap<(u256, ContractAddress), SealedBid>,
        
        // Marketplace storage
        listings: LegacyMap<u256, MarketplaceListing>,
        listing_counter: u256,
        
        // Fractional ownership
        fractional_ownerships: LegacyMap<u256, FractionalOwnership>,
        fractional_counter: u256,
        user_fractional_shares: LegacyMap<(u256, ContractAddress), u256>,
        
        // Anti-manipulation
        user_last_bid_time: LegacyMap<ContractAddress, u64>,
        min_bid_interval: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AuctionCreated: AuctionCreated,
        BidPlaced: BidPlaced,
        AuctionFinalized: AuctionFinalized,
        ListingCreated: ListingCreated,
        ItemSold: ItemSold,
        FractionalOwnershipCreated: FractionalOwnershipCreated,
        SharesPurchased: SharesPurchased,
        ContractPaused: ContractPaused,
        ContractUnpaused: ContractUnpaused,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionCreated {
        auction_id: u256,
        seller: ContractAddress,
        nft_contract: ContractAddress,
        token_id: u256,
        auction_type: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct BidPlaced {
        auction_id: u256,
        bidder: ContractAddress,
        bid_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionFinalized {
        auction_id: u256,
        winner: ContractAddress,
        final_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCreated {
        listing_id: u256,
        seller: ContractAddress,
        nft_contract: ContractAddress,
        token_id: u256,
        price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ItemSold {
        listing_id: u256,
        buyer: ContractAddress,
        price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct FractionalOwnershipCreated {
        fractional_id: u256,
        nft_contract: ContractAddress,
        token_id: u256,
        total_shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct SharesPurchased {
        fractional_id: u256,
        buyer: ContractAddress,
        shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractPaused {
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUnpaused {
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, fee_recipient: ContractAddress) {
        self.owner.write(owner);
        self.fee_recipient.write(fee_recipient);
        self.marketplace_fee.write(250); // 2.5% default fee
        self.min_bid_interval.write(60); // 1 minute minimum between bids
        self.auction_counter.write(1);
        self.listing_counter.write(1);
        self.fractional_counter.write(1);
    }

    #[abi(embed_v0)]
    impl GiftAuctionMarketplaceImpl of super::IGiftAuctionMarketplace<ContractState> {
        fn create_dutch_auction(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            start_price: u256,
            end_price: u256,
            duration: u64,
            payment_token: ContractAddress
        ) -> u256 {
            self._require_not_paused();
            self._require_nft_ownership(nft_contract, token_id);
            
            assert(start_price > end_price, 'Invalid price range');
            assert(duration > 0, 'Invalid duration');
            
            let auction_id = self.auction_counter.read();
            let current_time = get_block_timestamp();
            
            let auction = AuctionData {
                seller: get_caller_address(),
                nft_contract,
                token_id,
                start_price,
                end_price,
                reserve_price: end_price,
                start_time: current_time,
                end_time: current_time + duration,
                highest_bidder: starknet::contract_address_const::<0>(),
                highest_bid: 0,
                auction_type: 0, // Dutch auction
                is_active: true,
                payment_token,
            };
            
            self.auctions.write(auction_id, auction);
            self.auction_counter.write(auction_id + 1);
            
            // Transfer NFT to contract
            IERC721Dispatcher { contract_address: nft_contract }
                .transfer_from(get_caller_address(), get_contract_address(), token_id);
            
            self.emit(AuctionCreated {
                auction_id,
                seller: get_caller_address(),
                nft_contract,
                token_id,
                auction_type: 0,
            });
            
            auction_id
        }

        fn create_english_auction(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            starting_price: u256,
            reserve_price: u256,
            duration: u64,
            payment_token: ContractAddress
        ) -> u256 {
            self._require_not_paused();
            self._require_nft_ownership(nft_contract, token_id);
            
            assert(reserve_price >= starting_price, 'Reserve below starting price');
            assert(duration > 0, 'Invalid duration');
            
            let auction_id = self.auction_counter.read();
            let current_time = get_block_timestamp();
            
            let auction = AuctionData {
                seller: get_caller_address(),
                nft_contract,
                token_id,
                start_price: starting_price,
                end_price: 0,
                reserve_price,
                start_time: current_time,
                end_time: current_time + duration,
                highest_bidder: starknet::contract_address_const::<0>(),
                highest_bid: 0,
                auction_type: 1, // English auction
                is_active: true,
                payment_token,
            };
            
            self.auctions.write(auction_id, auction);
            self.auction_counter.write(auction_id + 1);
            
            // Transfer NFT to contract
            IERC721Dispatcher { contract_address: nft_contract }
                .transfer_from(get_caller_address(), get_contract_address(), token_id);
            
            self.emit(AuctionCreated {
                auction_id,
                seller: get_caller_address(),
                nft_contract,
                token_id,
                auction_type: 1,
            });
            
            auction_id
        }

        fn create_sealed_bid_auction(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            reserve_price: u256,
            bid_duration: u64,
            reveal_duration: u64,
            payment_token: ContractAddress
        ) -> u256 {
            self._require_not_paused();
            self._require_nft_ownership(nft_contract, token_id);
            
            let auction_id = self.auction_counter.read();
            let current_time = get_block_timestamp();
            
            let auction = AuctionData {
                seller: get_caller_address(),
                nft_contract,
                token_id,
                start_price: 0,
                end_price: 0,
                reserve_price,
                start_time: current_time,
                end_time: current_time + bid_duration + reveal_duration,
                highest_bidder: starknet::contract_address_const::<0>(),
                highest_bid: 0,
                auction_type: 3, // Sealed bid auction
                is_active: true,
                payment_token,
            };
            
            self.auctions.write(auction_id, auction);
            self.auction_counter.write(auction_id + 1);
            
            // Transfer NFT to contract
            IERC721Dispatcher { contract_address: nft_contract }
                .transfer_from(get_caller_address(), get_contract_address(), token_id);
            
            self.emit(AuctionCreated {
                auction_id,
                seller: get_caller_address(),
                nft_contract,
                token_id,
                auction_type: 3,
            });
            
            auction_id
        }

        fn place_bid(ref self: ContractState, auction_id: u256, bid_amount: u256) {
            self._require_not_paused();
            self._check_bid_interval();
            
            let mut auction = self.auctions.read(auction_id);
            assert(auction.is_active, 'Auction not active');
            assert(get_block_timestamp() <= auction.end_time, 'Auction ended');
            
            let caller = get_caller_address();
            assert(caller != auction.seller, 'Seller cannot bid');
            
            match auction.auction_type {
                0 => { // Dutch auction
                    let current_price = calculate_dutch_price(
                        auction.start_price,
                        auction.end_price,
                        auction.start_time,
                        auction.end_time,
                        get_block_timestamp()
                    );
                    assert(bid_amount >= current_price, 'Bid below current price');
                    self._finalize_dutch_auction(auction_id, caller, bid_amount);
                },
                1 => { // English auction
                    assert(bid_amount > auction.highest_bid, 'Bid too low');
                    assert(bid_amount >= auction.start_price, 'Bid below starting price');
                    
                    // Refund previous highest bidder
                    if auction.highest_bidder.into() != 0 {
                        IERC20Dispatcher { contract_address: auction.payment_token }
                            .transfer(auction.highest_bidder, auction.highest_bid);
                    }
                    
                    // Transfer bid amount from bidder
                    IERC20Dispatcher { contract_address: auction.payment_token }
                        .transfer_from(caller, get_contract_address(), bid_amount);
                    
                    auction.highest_bidder = caller;
                    auction.highest_bid = bid_amount;
                    self.auctions.write(auction_id, auction);
                    
                    self.emit(BidPlaced { auction_id, bidder: caller, bid_amount });
                },
                _ => assert(false, 'Invalid auction type for bid'),
            }
            
            self.user_last_bid_time.write(caller, get_block_timestamp());
        }

        fn place_sealed_bid(ref self: ContractState, auction_id: u256, bid_hash: felt252) {
            self._require_not_paused();
            
            let auction = self.auctions.read(auction_id);
            assert(auction.is_active, 'Auction not active');
            assert(auction.auction_type == 3, 'Not a sealed bid auction');
            
            let current_time = get_block_timestamp();
            let bid_end_time = auction.start_time + (auction.end_time - auction.start_time) / 2;
            assert(current_time <= bid_end_time, 'Bidding period ended');
            
            let caller = get_caller_address();
            assert(caller != auction.seller, 'Seller cannot bid');
            
            let sealed_bid = SealedBid {
                bidder: caller,
                bid_hash,
                revealed: false,
                bid_amount: 0,
            };
            
            self.sealed_bids.write((auction_id, caller), sealed_bid);
        }

        fn reveal_sealed_bid(ref self: ContractState, auction_id: u256, bid_amount: u256, nonce: felt252) {
            self._require_not_paused();
            
            let auction = self.auctions.read(auction_id);
            assert(auction.is_active, 'Auction not active');
            assert(auction.auction_type == 3, 'Not a sealed bid auction');
            
            let current_time = get_block_timestamp();
            let bid_end_time = auction.start_time + (auction.end_time - auction.start_time) / 2;
            assert(current_time > bid_end_time, 'Still in bidding period');
            assert(current_time <= auction.end_time, 'Reveal period ended');
            
            let caller = get_caller_address();
            let mut sealed_bid = self.sealed_bids.read((auction_id, caller));
            assert(!sealed_bid.revealed, 'Bid already revealed');
            
            // Verify bid hash
            let computed_hash = compute_hash(bid_amount, nonce);
            assert(computed_hash == sealed_bid.bid_hash, 'Invalid bid reveal');
            
            sealed_bid.revealed = true;
            sealed_bid.bid_amount = bid_amount;
            self.sealed_bids.write((auction_id, caller), sealed_bid);
            
            // Transfer bid amount
            IERC20Dispatcher { contract_address: auction.payment_token }
                .transfer_from(caller, get_contract_address(), bid_amount);
        }

        fn finalize_auction(ref self: ContractState, auction_id: u256) {
            self._require_not_paused();
            
            let mut auction = self.auctions.read(auction_id);
            assert(auction.is_active, 'Auction not active');
            assert(get_block_timestamp() > auction.end_time, 'Auction still active');
            
            match auction.auction_type {
                1 => { // English auction
                    if auction.highest_bid >= auction.reserve_price {
                        self._transfer_nft_and_payment(auction_id, auction.highest_bidder, auction.highest_bid);
                    } else {
                        // Reserve not met, return NFT to seller and refund highest bidder
                        IERC721Dispatcher { contract_address: auction.nft_contract }
                            .transfer_from(get_contract_address(), auction.seller, auction.token_id);
                        
                        if auction.highest_bidder.into() != 0 {
                            IERC20Dispatcher { contract_address: auction.payment_token }
                                .transfer(auction.highest_bidder, auction.highest_bid);
                        }
                    }
                },
                3 => { // Sealed bid auction
                    self._finalize_sealed_bid_auction(auction_id);
                },
                _ => assert(false, 'Invalid auction type for finalization'),
            }
            
            auction.is_active = false;
            self.auctions.write(auction_id, auction);
        }

        fn get_dutch_price(self: @ContractState, auction_id: u256) -> u256 {
            let auction = self.auctions.read(auction_id);
            calculate_dutch_price(
                auction.start_price,
                auction.end_price,
                auction.start_time,
                auction.end_time,
                get_block_timestamp()
            )
        }

        fn create_listing(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            price: u256,
            payment_token: ContractAddress
        ) -> u256 {
            self._require_not_paused();
            self._require_nft_ownership(nft_contract, token_id);
            
            let listing_id = self.listing_counter.read();
            
            let listing = MarketplaceListing {
                seller: get_caller_address(),
                nft_contract,
                token_id,
                price,
                payment_token,
                is_active: true,
                created_at: get_block_timestamp(),
            };
            
            self.listings.write(listing_id, listing);
            self.listing_counter.write(listing_id + 1);
            
            // Transfer NFT to contract
            IERC721Dispatcher { contract_address: nft_contract }
                .transfer_from(get_caller_address(), get_contract_address(), token_id);
            
            self.emit(ListingCreated {
                listing_id,
                seller: get_caller_address(),
                nft_contract,
                token_id,
                price,
            });
            
            listing_id
        }

        fn buy_now(ref self: ContractState, listing_id: u256) {
            self._require_not_paused();
            
            let mut listing = self.listings.read(listing_id);
            assert(listing.is_active, 'Listing not active');
            
            let caller = get_caller_address();
            assert(caller != listing.seller, 'Cannot buy own listing');
            
            // Transfer payment
            IERC20Dispatcher { contract_address: listing.payment_token }
                .transfer_from(caller, get_contract_address(), listing.price);
            
            // Calculate and distribute fees
            let fee_amount = (listing.price * self.marketplace_fee.read()) / 10000;
            let seller_amount = listing.price - fee_amount;
            
            IERC20Dispatcher { contract_address: listing.payment_}token }
                .transfer(self.fee_recipient.read(), fee_amount);
            IERC20Dispatcher { contract_address: listing.payment_token }
                .transfer(listing.seller, seller_amount);
            IERC721Dispatcher { contract_address: listing.nft_contract }
                .transfer_from(get_contract_address(), caller, listing.token_id);
            listing.is_active = false;
            self.listings.write(listing_id, listing);
            self.emit(ItemSold {
                listing_id,
                buyer: caller,
                price: listing.price,
            });
        }
        fn cancel_listing(ref self: ContractState, listing_id: u256) {
            self._require_not_paused();
            
            let mut listing = self.listings.read(listing_id);
            assert(listing.is_active, 'Listing not active');
            assert(get_caller_address() == listing.seller, 'Only seller can cancel');
            
            // Return NFT to seller
            IERC721Dispatcher { contract_address: listing.nft_contract }
                .transfer_from(get_contract_address(), listing.seller, listing.token_id);
            
            listing.is_active = false;
            self.listings.write(listing_id, listing);
        }
        fn create_fractional_ownership(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            total_shares: u256,
            price_per_share: u256
        ) -> u256 {
            self._require_not_paused();
            self._require_nft_ownership(nft_contract, token_id);
            
            assert(total_shares > 0, 'Invalid total shares');
            assert(price_per_share > 0, 'Invalid price per share');
            
            let fractional_id = self.fractional_counter.read();
            
            let fractional_ownership = FractionalOwnership {
                nft_contract,
                token_id,
                total_shares,
                price_per_share,
                shares_sold: 0,
                is_active: true,
                created_at: get_block_timestamp(),
            };
            
            self.fractional_ownerships.write(fractional_id, fractional_ownership);
            self.fractional_counter.write(fractional_id + 1);
            
            // Transfer NFT to contract
            IERC721Dispatcher { contract_address: nft_contract }
                .transfer_from(get_caller_address(), get_contract_address(), token_id);
            
            self.emit(FractionalOwnershipCreated {
                fractional_id,
                nft_contract,
                token_id,
                total_shares,
            });
            
            fractional_id
        }
        fn buy_shares(ref self: ContractState, fractional_id: u256, shares: u256) {
            self._require_not_paused();
            
            let mut fractional = self.fractional_ownerships.read(fractional_id);
            assert(fractional.is_active, 'Fractional ownership not active');
            assert(shares > 0, 'Invalid shares amount');
            assert(fractional.shares_sold + shares <= fractional.total_shares, 'Not enough shares available');
            
            let total_price = shares * fractional.price_per_share;
            let caller = get_caller_address();
            
            // Transfer payment
            IERC20Dispatcher { contract_address: fractional.payment_token }
                .transfer_from(caller, get_contract_address(), total_price);
            
            // Update shares sold
            fractional.shares_sold += shares;
            self.fractional_ownerships.write(fractional_id, fractional);
            
            // Record user shares
            let user_key = (fractional_id, caller);
            let current_shares = self.user_fractional_shares.read(user_key);
            self.user_fractional_shares.write(user_key, current_shares + shares);
            
            self.emit(SharesPurchased {
                fractional_id,
                buyer: caller,     
                shares,
            });
        }
        fn set_marketplace_fee(ref self: ContractState, fee_percentage: u256) {
            self._require_owner();
            assert(fee_percentage <= 10000, 'Fee too high'); // 100% max
            self.marketplace_fee.write(fee_percentage);
        }
        fn set_fee_recipient(ref self: ContractState, recipient: ContractAddress) {
            self._require_owner();
            assert(recipient != starknet::contract_address_const::<0>(), 'Invalid recipient');
            self.fee_recipient.write(recipient);
        }
        fn pause_contract(ref self: ContractState) {
            self._require_owner();
            self.paused.write(true);
            self.emit(ContractPaused { timestamp: get_block_timestamp() });
        }

        // ...existing code...

        fn unpause_contract(ref self: ContractState) {
            self._require_owner();
            self.paused.write(false);
            self.emit(ContractUnpaused { timestamp: get_block_timestamp() });
        }

        fn emergency_withdraw(ref self: ContractState, token: ContractAddress) {
            self._require_owner();

            // Query contract's token balance
            let contract_address = get_contract_address();
            let balance = IERC20Dispatcher { contract_address: token }
                .balance_of(contract_address);

            assert(balance > 0, 'No tokens to withdraw');

            // Transfer all tokens to owner
            IERC20Dispatcher { contract_address: token }
                .transfer(self.owner.read(), balance);
        }

        fn get_auction(self: @ContractState, auction_id: u256) -> AuctionData {
            self.auctions.read(auction_id)
        }

        fn get_listing(self: @ContractState, listing_id: u256) -> MarketplaceListing {
            self.listings.read(listing_id)
        }

        fn get_fractional_ownership(self: @ContractState, fractional_id: u256) -> FractionalOwnership {
            self.fractional_ownerships.read(fractional_id)
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
