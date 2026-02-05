module lootbox_game::lootbox_game {

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::random;
    use sui::sui::SUI;
    use sui::dynamic_field as df;
    use std::string;
    use std::string::String;

    /// -----------------------------
    /// ADMIN CAPABILITY
    /// -----------------------------
    struct AdminCap has key {
        id: UID
    }

    /// -----------------------------
    /// GAME CONFIG (SHARED OBJECT)
    /// -----------------------------
    struct GameConfig has key {
        id: UID,

        loot_box_price: u64,

        common_weight: u8,
        rare_weight: u8,
        epic_weight: u8,
        legendary_weight: u8
    }

    /// -----------------------------
    /// PITY COUNTER (PER USER)
    /// -----------------------------
    struct PityCounter has key {
        id: UID,
        opens_without_legendary: u64
    }

    /// -----------------------------
    /// LOOT BOX (UNOPENED)
    /// -----------------------------
    struct LootBox has key {
        id: UID
    }

    /// -----------------------------
    /// GAME ITEM (NFT)
    /// -----------------------------
    struct GameItem has key, store {
        id: UID,
        name: String,
        rarity: u8, // 0=Common,1=Rare,2=Epic,3=Legendary
        power: u64
    }

    /// -----------------------------
    /// EVENT
    /// -----------------------------
    struct LootBoxOpened has copy, drop {
        item_id: address,
        rarity: u8,
        power: u64,
        owner: address
    }

    /// -----------------------------
    /// INIT GAME (ONE TIME)
    /// -----------------------------
    public entry fun init_game(ctx: &mut TxContext) {
        let admin = AdminCap { id: object::new(ctx) };

        let config = GameConfig {
            id: object::new(ctx),
            loot_box_price: 1_000_000_000, // 1 SUI

            common_weight: 60,
            rare_weight: 25,
            epic_weight: 12,
            legendary_weight: 3
        };

        transfer::share_object(config);
        transfer::transfer(admin, tx_context::sender(ctx));
    }

    /// -----------------------------
    /// PURCHASE LOOT BOX
    /// -----------------------------
    public entry fun purchase_loot_box(
        config: &GameConfig,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let price = config.loot_box_price;
        let paid = coin::value(&payment);
        assert!(paid == price, 0);

        // Burn payment
        coin::destroy(payment);

        let loot_box = LootBox {
            id: object::new(ctx)
        };

        transfer::transfer(loot_box, tx_context::sender(ctx));
    }

    /// -----------------------------
    /// OPEN LOOT BOX (RANDOM + PITY)
    /// -----------------------------
    public entry fun open_loot_box(
        config: &mut GameConfig,
        loot_box: LootBox,
        r: &random::Random,
        ctx: &mut TxContext
    ) {
        let LootBox { id } = loot_box;
        object::delete(id);

        let sender = tx_context::sender(ctx);
        let mut gen = random::new_generator(ctx, r);

        // Ensure pity counter exists
        if (!df::exists<&address, PityCounter>(&config.id, sender)) {
            df::add<&address, PityCounter>(
                &mut config.id,
                sender,
                PityCounter {
                    id: object::new(ctx),
                    opens_without_legendary: 0
                }
            );
        };

        let pity = df::borrow_mut<&address, PityCounter>(&mut config.id, sender);

        let rarity: u8;
        let power: u64;

        // Pity rule
        if (pity.opens_without_legendary >= 30) {
            rarity = 3;
            power = random::generate_u64_in_range(&mut gen, 41, 50);
            pity.opens_without_legendary = 0;
        } else {
            let roll = random::generate_u8_in_range(&mut gen, 0, 99);

            let c = config.common_weight;
            let r_ = c + config.rare_weight;
            let e = r_ + config.epic_weight;

            if (roll < c) {
                rarity = 0;
                power = random::generate_u64_in_range(&mut gen, 1, 10);
                pity.opens_without_legendary = pity.opens_without_legendary + 1;
            } else if (roll < r_) {
                rarity = 1;
                power = random::generate_u64_in_range(&mut gen, 11, 25);
                pity.opens_without_legendary = pity.opens_without_legendary + 1;
            } else if (roll < e) {
                rarity = 2;
                power = random::generate_u64_in_range(&mut gen, 26, 40);
                pity.opens_without_legendary = pity.opens_without_legendary + 1;
            } else {
                rarity = 3;
                power = random::generate_u64_in_range(&mut gen, 41, 50);
                pity.opens_without_legendary = 0;
            };
        };

        let name = if (rarity == 0) {
            string::utf8(b"Common Item")
        } else if (rarity == 1) {
            string::utf8(b"Rare Item")
        } else if (rarity == 2) {
            string::utf8(b"Epic Item")
        } else {
            string::utf8(b"Legendary Item")
        };

        let item = GameItem {
            id: object::new(ctx),
            name,
            rarity,
            power
        };

        let item_id = object::id(&item);

        event::emit(LootBoxOpened {
            item_id,
            rarity,
            power,
            owner: sender
        });

        transfer::transfer(item, sender);
    }

    /// -----------------------------
    /// VIEW ITEM STATS
    /// -----------------------------
    public fun get_item_stats(item: &GameItem): (String, u8, u64) {
        (item.name, item.rarity, item.power)
    }

    /// -----------------------------
    /// TRANSFER ITEM
    /// -----------------------------
    public entry fun transfer_item(
        item: GameItem,
        recipient: address
    ) {
        transfer::transfer(item, recipient);
    }

    /// -----------------------------
    /// BURN ITEM
    /// -----------------------------
    public entry fun burn_item(item: GameItem) {
        let GameItem { id, name: _, rarity: _, power: _ } = item;
        object::delete(id);
    }

    /// -----------------------------
    /// UPDATE RARITY WEIGHTS (ADMIN)
    /// -----------------------------
    public entry fun update_rarity_weights(
        _admin: &AdminCap,
        config: &mut GameConfig,
        common: u8,
        rare: u8,
        epic: u8,
        legendary: u8
    ) {
        assert!(
            (common as u64)
                + (rare as u64)
                + (epic as u64)
                + (legendary as u64)
                == 100,
            1
        );

        config.common_weight = common;
        config.rare_weight = rare;
        config.epic_weight = epic;
        config.legendary_weight = legendary;
    }
}