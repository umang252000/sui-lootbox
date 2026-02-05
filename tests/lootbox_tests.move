module lootbox_game::lootbox_tests {

    use sui::test_scenario;
    use sui::tx_context::TxContext;
    use sui::object;
    use sui::coin;
    use sui::transfer;

    use lootbox_game::lootbox_game::{
        init_game,
        purchase_loot_box,
        get_item_stats,
        LootBox,
        GameItem,
        GameConfig
    };

    /// --------------------------------
    /// TEST 1: Game Initialization
    /// --------------------------------
    #[test]
    fun test_init_game() {
        let mut scenario = test_scenario::begin();
        let ctx = test_scenario::ctx(&mut scenario);

        // Call init
        init_game(ctx);

        // If init_game fails, test fails automatically
        test_scenario::end(scenario);
    }

    /// --------------------------------
    /// TEST 2: Purchase Loot Box
    /// --------------------------------
    #[test]
    fun test_purchase_loot_box() {
        let mut scenario = test_scenario::begin();
        let ctx = test_scenario::ctx(&mut scenario);

        // Initialize game
        init_game(ctx);

        // Get shared GameConfig
        let config = test_scenario::take_shared<GameConfig>(&mut scenario);

        // Mint test SUI coin (1 SUI)
        let payment = coin::mint_for_testing<sui::sui::SUI>(1_000_000_000, ctx);

        // Purchase loot box
        purchase_loot_box(&config, payment, ctx);

        test_scenario::end(scenario);
    }

    /// --------------------------------
    /// TEST 3: NFT Stats Read
    /// --------------------------------
    #[test]
    fun test_get_item_stats() {
        let mut scenario = test_scenario::begin();
        let ctx = test_scenario::ctx(&mut scenario);

        // Create dummy NFT
        let item = GameItem {
            id: object::new(ctx),
            name: std::string::utf8(b"Test Item"),
            rarity: 1,
            power: 20
        };

        let (name, rarity, power) = get_item_stats(&item);

        assert!(rarity == 1, 0);
        assert!(power == 20, 1);
        assert!(name == std::string::utf8(b"Test Item"), 2);

        test_scenario::end(scenario);
    }

}