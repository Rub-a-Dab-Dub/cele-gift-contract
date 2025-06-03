#[starknet::contract]
pub mod RubDub {
    use cele_gift_contract::base::types::{Celebrity, GiftCategory, GiftMetadata, Rarity};
    use cele_gift_contract::interfaces::IRubDubNFT::IRubDubNFT;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, contract_address_const, get_caller_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        celebrity_id_count: u256,
        token_id_count: u256,
        royaltyPercentage: u256,
        celebrities: Map<ContractAddress, Celebrity>,
        celebrities_id: Map<u256, Celebrity>,
        gift_metadata: Map<u256, GiftMetadata>,
        individual_gifts: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        CelebrityCreated: CelebrityCreated,
        GiftMinted: GiftMinted,
        CelebrityVerified: CelebrityVerified,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CelebrityCreated {
        #[key]
        pub id: u256,
        pub celebrityname: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CelebrityVerified {
        pub id: u256,
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GiftMinted {
        #[key]
        pub token_id: u256,
        pub recipient: ContractAddress,
        pub category: GiftCategory,
        pub celebrity_id: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let base_uri = "uri";
        let name = "RubDub";
        let symbol = "RDU";
        self.erc721.initializer(name, symbol, base_uri);
        self.royaltyPercentage.write(10);
    }

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721MixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl RubDub of IRubDubNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            self.erc721.mint(recipient, token_id);
        }

        fn owner(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.erc721.owner_of(token_id);
            owner
        }
        fn gift_token(
            ref self: ContractState,
            token: ContractAddress,
            receiver: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token };

            let caller_balance = erc20_dispatcher.balance_of(caller);
            assert(caller_balance >= amount, 'insufficient bal');
            let success = erc20_dispatcher.transfer(receiver, amount);

            let previous_gifts = self.individual_gifts.read((caller, receiver));
            self.individual_gifts.write((caller, receiver), (amount + previous_gifts));

            success
        }

        fn mint_gift(
            ref self: ContractState,
            recipient: ContractAddress,
            category: GiftCategory,
            rarity: Rarity,
            celebrity_id: u256,
            token_uri: ByteArray,
        ) {
            let token_id = self.token_id_count.read() + 1;
            let celeb = self.celebrities_id.read(celebrity_id);
            assert(celeb.registered, 'Celebrity not found');

            self.erc721.mint(recipient, token_id);

            let metadata = GiftMetadata { token_id, category, rarity, celebrity_id, token_uri };

            self.token_id_count.write(token_id);
            self.gift_metadata.write(token_id, metadata);
            self.emit(GiftMinted { token_id, recipient, category, celebrity_id });
        }

        fn batch_mint_gifts(
            ref self: ContractState,
            recipient: ContractAddress,
            count: u32,
            category: GiftCategory,
            rarity: Rarity,
            celebrity_id: u256,
            token_uri: ByteArray,
        ) {
            let mut i = 0;
            while (i < count) {
                self
                    .mint_gift(
                        recipient, category, rarity.clone(), celebrity_id, token_uri.clone(),
                    );
                i += 1;
            }
        }

        fn is_owner(ref self: ContractState, token_id: u256) -> ContractAddress {
            self.erc721.ownerOf(token_id)
        }

        fn get_name(self: @ContractState) -> ByteArray {
            self.erc721.name()
        }

        fn get_symbol(self: @ContractState) -> ByteArray {
            self.erc721.symbol()
        }

        fn register_celebrity(
            ref self: ContractState, address: ContractAddress, celebrityname: felt252,
        ) -> u256 {
            let cele = self.celebrities.read(address);
            assert(!cele.registered, 'Already registered');

            let id = self.celebrity_id_count.read() + 1;
            self.celebrity_id_count.write(id);

            let manager: ContractAddress = contract_address_const::<'0x0'>();

            let celebrity = Celebrity {
                id,
                address,
                celebrityname,
                verified: false,
                royaltyPercentage: self.royaltyPercentage.read(),
                registered: true,
                manager,
                preferences: GiftCategory::NoneSet,
            };

            self.celebrities.write(address, celebrity);
            self.celebrities_id.write(id, celebrity);

            self.emit(CelebrityCreated { id, celebrityname });

            id
        }

        fn verify_celebrity(ref self: ContractState, address: ContractAddress) {
            let mut celeb = self.celebrities.read(address);
            assert(celeb.registered, 'Celebrity not registered');
            celeb.verified = true;
            self.celebrities.write(address, celeb);
            self.celebrities_id.write(celeb.id, celeb);
            self.emit(CelebrityVerified { id: celeb.id, address });
        }

        fn set_gift_preferences(
            ref self: ContractState, celebrity_address: ContractAddress, preferences: GiftCategory,
        ) {
            let mut celeb = self.celebrities.read(celebrity_address);
            assert(celeb.registered, 'Celebrity not registered');
            celeb.preferences = preferences;
            self.celebrities.write(celebrity_address, celeb);
            self.celebrities_id.write(celeb.id, celeb);
        }

        fn delegate_manager(
            ref self: ContractState, celebrity_address: ContractAddress, manager: ContractAddress,
        ) {
            let caller = get_caller_address();
            let mut celeb = self.celebrities.read(celebrity_address);
            assert(celeb.registered, 'Celebrity not registered');
            assert(caller == celeb.address, 'No authorization');
            celeb.manager = manager;
            self.celebrities.write(celebrity_address, celeb);
            self.celebrities_id.write(celeb.id, celeb);
        }
        fn get_manager(self: @ContractState, celebrity_id: u256) -> ContractAddress {
            let celeb = self.celebrities_id.read(celebrity_id);
            celeb.manager
        }

        fn get_preferences(self: @ContractState, celebrity_id: u256) -> GiftCategory {
            let celeb = self.celebrities_id.read(celebrity_id);
            celeb.preferences
        }

        fn get_celebrity(self: @ContractState, celebrity_id: u256) -> Celebrity {
            self.celebrities_id.read(celebrity_id)
        }

        fn get_metadata(self: @ContractState, token_id: u256) -> GiftMetadata {
            self.gift_metadata.read(token_id)
        }
    }
}
