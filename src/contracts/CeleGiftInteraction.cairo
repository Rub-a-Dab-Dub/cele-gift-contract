#[starknet::contract]

use starknet::ContractAddress;


#[derive(Drop, Serde, starknet::Store)]
struct Gift {
    id: u256,
    sender: ContractAddress,
    recipient: ContractAddress,
    token_address: ContractAddress,
    amount: u256,
    message: felt252,
    unlockable_content_hash: felt252,
    is_premium: bool,
    timestamp: u64,
    response: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct AuctionItem {
    id: u256,
    seller: ContractAddress,
    current_bid: u256,
    highest_bidder: ContractAddress,
    end_time: u64,
    token_address: ContractAddress,
    is_active: bool,
}

#[starknet::interface]
trait ICeleGiftInteraction<TContractState> {
    // Gift Management
    fn send_gift(
        ref self: TContractState,
        recipient: ContractAddress,
        token_address: ContractAddress,
        amount: u256,
        message: felt252,
        unlockable_content_hash: felt252,
        is_premium: bool
    ) -> u256;
    
    fn send_batch_gifts(
        ref self: TContractState,
        recipients: Array<ContractAddress>,
        token_address: ContractAddress,
        amounts: Array<u256>,
        message: felt252
    );

    fn respond_to_gift(ref self: TContractState, gift_id: u256, response: felt252);
    
    // Unlockable Content
    fn reveal_unlockable_content(ref self: TContractState, gift_id: u256) -> felt252;
    
    // Auction System
    fn create_auction(
        ref self: TContractState,
        token_address: ContractAddress,
        starting_bid: u256,
        duration: u64
    ) -> u256;
    
    fn place_bid(ref self: TContractState, auction_id: u256, bid_amount: u256);
    fn end_auction(ref self: TContractState, auction_id: u256);
    
    // View Functions
    fn get_gift(self: @TContractState, gift_id: u256) -> Gift;
    fn get_auction(self: @TContractState, auction_id: u256) -> AuctionItem;
    fn get_user_gifts(self: @TContractState, user: ContractAddress) -> Array<Gift>;
}

#[starknet::contract]
mod CeleGiftInteraction {
    use core::num::traits::Zero;
use starknet::storage::Map;
use starknet::storage::StorageMapReadAccess;
use starknet::storage::StorageMapWriteAccess;
use starknet::storage::StoragePointerReadAccess;
use starknet::storage::StoragePointerWriteAccess;
use super::{Gift, AuctionItem, ContractAddress, ArrayTrait};
    use starknet::{get_caller_address, get_block_timestamp};
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;

    #[storage]
    struct Storage {
        gifts: Map<u256, Gift>,
        auctions: Map<u256, AuctionItem>,
        next_gift_id: u256,
        next_auction_id: u256,
        user_gifts: Map<(ContractAddress, u256), u256>,
        user_gift_count: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GiftSent: GiftSent,
        GiftResponse: GiftResponse,
        AuctionCreated: AuctionCreated,
        BidPlaced: BidPlaced,
        AuctionEnded: AuctionEnded,
    }

    #[derive(Drop, starknet::Event)]
    struct GiftSent {
        gift_id: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct GiftResponse {
        gift_id: u256,
        responder: ContractAddress,
        response: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionCreated {
        auction_id: u256,
        seller: ContractAddress,
        starting_bid: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BidPlaced {
        auction_id: u256,
        bidder: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionEnded {
        auction_id: u256,
        winner: ContractAddress,
        final_bid: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_gift_id.write(1);
        self.next_auction_id.write(1);
    }

    #[external(v0)]
    impl CeleGiftInteractionImpl of super::ICeleGiftInteraction<ContractState> {
        fn send_gift(
            ref self: ContractState,
            recipient: ContractAddress,
            token_address: ContractAddress,
            amount: u256,
            message: felt252,
            unlockable_content_hash: felt252,
            is_premium: bool
        ) -> u256 {
            assert(!recipient.is_zero(), 'Invalid recipient');
            assert(amount > 0, 'Amount must be positive');
            
            let caller = get_caller_address();
            let gift_id = self.next_gift_id.read();
            
            // Transfer tokens from sender to contract
            let token = IERC20Dispatcher { contract_address: token_address };
            token.transfer_from(caller, starknet::get_contract_address(), amount);
            
            // Create and store the gift
            let gift = Gift {
                id: gift_id,
                sender: caller,
                recipient,
                token_address,
                amount,
                message,
                unlockable_content_hash,
                is_premium,
                timestamp: get_block_timestamp(),
                response: 0,
            };
            
            self.gifts.write(gift_id, gift);
            
            // Update user gift tracking
            let user_count = self.user_gift_count.read(recipient);
            self.user_gifts.write((recipient, user_count), gift_id);
            self.user_gift_count.write(recipient, user_count + 1);
            
            self.next_gift_id.write(gift_id + 1);
            
            self.emit(GiftSent { gift_id, sender: caller, recipient, amount });
            
            gift_id
        }

        fn send_batch_gifts(
            ref self: ContractState,
            recipients: Array<ContractAddress>,
            token_address: ContractAddress,
            amounts: Array<u256>,
            message: felt252
        ) {
            assert(recipients.len() == amounts.len(), 'Arrays length mismatch');
            let caller = get_caller_address();
            
            let mut i: u32 = 0;
            loop {
                if i >= recipients.len() {
                    break;
                }
                
                self.send_gift(
                    *recipients.at(i),
                    token_address,
                    *amounts.at(i),
                    message,
                    0, // No unlockable content for batch gifts
                    false, // Not premium
                );
                
                i += 1;
            }
        }

        fn respond_to_gift(ref self: ContractState, gift_id: u256, response: felt252) {
            let mut gift = self.gifts.read(gift_id);
            assert(get_caller_address() == gift.recipient, 'Only recipient can respond');
            
            gift.response = response;
            self.gifts.write(gift_id, gift);
            
            self.emit(GiftResponse { 
                gift_id,
                responder: get_caller_address(),
                response,
            });
        }

        fn reveal_unlockable_content(ref self: ContractState, gift_id: u256) -> felt252 {
            let gift = self.gifts.read(gift_id);
            assert(get_caller_address() == gift.recipient, 'Only recipient can reveal');
            assert(gift.is_premium, 'Not a premium gift');
            
            gift.unlockable_content_hash
        }

        fn create_auction(
            ref self: ContractState,
            token_address: ContractAddress,
            starting_bid: u256,
            duration: u64
        ) -> u256 {
            assert(starting_bid > 0, 'Invalid starting bid');
            let auction_id = self.next_auction_id.read();
            
            let auction = AuctionItem {
                id: auction_id,
                seller: get_caller_address(),
                current_bid: starting_bid,
                highest_bidder: Zeroable::zero(),
                end_time: get_block_timestamp() + duration,
                token_address,
                is_active: true,
            };
            
            self.auctions.write(auction_id, auction);
            self.next_auction_id.write(auction_id + 1);
            
            self.emit(AuctionCreated {
                auction_id,
                seller: get_caller_address(),
                starting_bid,
            });
            
            auction_id
        }

        fn place_bid(ref self: ContractState, auction_id: u256, bid_amount: u256) {
            let mut auction = self.auctions.read(auction_id);
            assert(auction.is_active, 'Auction not active');
            assert(get_block_timestamp() < auction.end_time, 'Auction ended');
            assert(bid_amount > auction.current_bid, 'Bid too low');
            
            let caller = get_caller_address();
            let token = IERC20Dispatcher { contract_address: auction.token_address };
            
            // Return previous bid if exists
            if !auction.highest_bidder.is_zero() {
                token.transfer(auction.highest_bidder, auction.current_bid);
            }
            
            // Transfer new bid
            token.transfer_from(caller, starknet::get_contract_address(), bid_amount);
            
            auction.current_bid = bid_amount;
            auction.highest_bidder = caller;
            self.auctions.write(auction_id, auction);
            
            self.emit(BidPlaced {
                auction_id,
                bidder: caller,
                amount: bid_amount,
            });
        }

        fn end_auction(ref self: ContractState, auction_id: u256) {
            let mut auction = self.auctions.read(auction_id);
            assert(auction.is_active, 'Auction not active');
            assert(get_block_timestamp() >= auction.end_time, 'Auction not ended');
            
            auction.is_active = false;
            self.auctions.write(auction_id, auction);
            
            let token = IERC20Dispatcher { contract_address: auction.token_address };
            
            // Transfer winning bid to seller
            if !auction.highest_bidder.is_zero() {
                token.transfer(auction.seller, auction.current_bid);
            }
            
            self.emit(AuctionEnded {
                auction_id,
                winner: auction.highest_bidder,
                final_bid: auction.current_bid,
            });
        }

        fn get_gift(self: @ContractState, gift_id: u256) -> Gift {
            self.gifts.read(gift_id)
        }

        fn get_auction(self: @ContractState, auction_id: u256) -> AuctionItem {
            self.auctions.read(auction_id)
        }

        fn get_user_gifts(self: @ContractState, user: ContractAddress) -> Array<Gift> {
            let mut gifts = ArrayTrait::new();
            let count = self.user_gift_count.read(user);
            
            let mut i: u256 = 0;
            loop {
                if i >= count {
                    break;
                }
                
                let gift_id = self.user_gifts.read((user, i));
                let gift = self.gifts.read(gift_id);
                gifts.append(gift);
                
                i += 1;
            };
            
            gifts
        }
    }
} 