#[cfg(test)]
mod tests {
    use core::traits::Into;
    use array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::testing::{set_caller_address, set_contract_address, set_block_timestamp};
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank};
    use cele_gift_contract::contracts::CeleGiftInteraction::{
        CeleGiftInteraction, ICeleGiftInteractionDispatcher, ICeleGiftInteractionDispatcherTrait
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    fn deploy_contract() -> ContractAddress {
        let contract = declare('CeleGiftInteraction');
        contract.deploy(@ArrayTrait::new()).unwrap()
    }

    fn setup_test_token() -> ContractAddress {
        // Deploy a test ERC20 token for testing
        let contract = declare('GiftToken');
        let constructor_args = array![
            1234.into(), // recipient
            1234.into(), // owner
            18.into(), // decimals
        ];
        contract.deploy(@constructor_args).unwrap()
    }

    #[test]
    fn test_send_gift() {
        let contract_address = deploy_contract();
        let token_address = setup_test_token();
        let dispatcher = ICeleGiftInteractionDispatcher { contract_address };
        let token = IERC20Dispatcher { contract_address: token_address };

        let sender: ContractAddress = 1234.into();
        let recipient: ContractAddress = 5678.into();
        let amount: u256 = 1000.into();

        // Setup approvals and balances
        start_prank(token_address, sender);
        token.approve(contract_address, amount);
        stop_prank(token_address);

        // Send gift
        start_prank(contract_address, sender);
        let gift_id = dispatcher.send_gift(
            recipient,
            token_address,
            amount,
            'Thank you for being awesome!'.into(),
            'secret_content'.into(),
            true
        );
        stop_prank(contract_address);

        // Verify gift details
        let gift = dispatcher.get_gift(gift_id);
        assert(gift.sender == sender, 'Wrong sender');
        assert(gift.recipient == recipient, 'Wrong recipient');
        assert(gift.amount == amount, 'Wrong amount');
        assert(gift.is_premium == true, 'Wrong premium status');
    }

    #[test]
    fn test_batch_gifts() {
        let contract_address = deploy_contract();
        let token_address = setup_test_token();
        let dispatcher = ICeleGiftInteractionDispatcher { contract_address };

        let sender: ContractAddress = 1234.into();
        let mut recipients = ArrayTrait::new();
        recipients.append(5678.into());
        recipients.append(9012.into());

        let mut amounts = ArrayTrait::new();
        amounts.append(1000.into());
        amounts.append(2000.into());

        // Setup approvals
        start_prank(token_address, sender);
        token.approve(contract_address, 3000.into());
        stop_prank(token_address);

        // Send batch gifts
        start_prank(contract_address, sender);
        dispatcher.send_batch_gifts(
            recipients,
            token_address,
            amounts,
            'Group gift!'.into()
        );
        stop_prank(contract_address);

        // Verify gifts were created
        let recipient_gifts = dispatcher.get_user_gifts(5678.into());
        assert(recipient_gifts.len() == 1, 'Wrong gift count');
    }

    #[test]
    fn test_auction_flow() {
        let contract_address = deploy_contract();
        let token_address = setup_test_token();
        let dispatcher = ICeleGiftInteractionDispatcher { contract_address };

        let seller: ContractAddress = 1234.into();
        let bidder1: ContractAddress = 5678.into();
        let bidder2: ContractAddress = 9012.into();

        // Create auction
        start_prank(contract_address, seller);
        let auction_id = dispatcher.create_auction(
            token_address,
            1000.into(), // starting bid
            3600 // 1 hour duration
        );
        stop_prank(contract_address);

        // Setup bidder1
        start_prank(token_address, bidder1);
        token.approve(contract_address, 2000.into());
        stop_prank(token_address);

        // First bid
        start_prank(contract_address, bidder1);
        dispatcher.place_bid(auction_id, 1500.into());
        stop_prank(contract_address);

        // Setup bidder2
        start_prank(token_address, bidder2);
        token.approve(contract_address, 3000.into());
        stop_prank(token_address);

        // Second bid
        start_prank(contract_address, bidder2);
        dispatcher.place_bid(auction_id, 2000.into());
        stop_prank(contract_address);

        // Advance time
        set_block_timestamp(get_block_timestamp() + 3601);

        // End auction
        start_prank(contract_address, seller);
        dispatcher.end_auction(auction_id);
        stop_prank(contract_address);

        // Verify auction result
        let auction = dispatcher.get_auction(auction_id);
        assert(!auction.is_active, 'Auction should be inactive');
        assert(auction.highest_bidder == bidder2, 'Wrong winner');
        assert(auction.current_bid == 2000.into(), 'Wrong final bid');
    }

    #[test]
    fn test_gift_response() {
        let contract_address = deploy_contract();
        let token_address = setup_test_token();
        let dispatcher = ICeleGiftInteractionDispatcher { contract_address };

        let sender: ContractAddress = 1234.into();
        let celebrity: ContractAddress = 5678.into();
        let amount: u256 = 1000.into();

        // Setup and send gift
        start_prank(token_address, sender);
        token.approve(contract_address, amount);
        stop_prank(token_address);

        start_prank(contract_address, sender);
        let gift_id = dispatcher.send_gift(
            celebrity,
            token_address,
            amount,
            'Love your work!'.into(),
            0.into(),
            false
        );
        stop_prank(contract_address);

        // Celebrity responds
        start_prank(contract_address, celebrity);
        dispatcher.respond_to_gift(gift_id, 'Thank you for your support!'.into());
        stop_prank(contract_address);

        // Verify response
        let gift = dispatcher.get_gift(gift_id);
        assert(gift.response == 'Thank you for your support!'.into(), 'Wrong response');
    }

    #[test]
    fn test_unlockable_content() {
        let contract_address = deploy_contract();
        let token_address = setup_test_token();
        let dispatcher = ICeleGiftInteractionDispatcher { contract_address };

        let sender: ContractAddress = 1234.into();
        let recipient: ContractAddress = 5678.into();
        let amount: u256 = 1000.into();
        let content_hash = 'exclusive_content_hash'.into();

        // Setup and send premium gift
        start_prank(token_address, sender);
        token.approve(contract_address, amount);
        stop_prank(token_address);

        start_prank(contract_address, sender);
        let gift_id = dispatcher.send_gift(
            recipient,
            token_address,
            amount,
            'Special gift!'.into(),
            content_hash,
            true
        );
        stop_prank(contract_address);

        // Recipient reveals content
        start_prank(contract_address, recipient);
        let revealed_content = dispatcher.reveal_unlockable_content(gift_id);
        stop_prank(contract_address);

        assert(revealed_content == content_hash, 'Wrong content revealed');
    }
} 