module burnbutton::arena_factory {
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};

    /// Error codes
    const E_NOT_INITIALIZED: u64 = 1;
    const E_ROUND_NOT_ACTIVE: u64 = 2;
    const E_TIMER_STILL_RUNNING: u64 = 3;
    const E_MAX_CLICKS_REACHED: u64 = 4;
    const E_NO_REWARDS_AVAILABLE: u64 = 5;

    /// Configuration & State for an individual Token Arena
    struct ArenaConfig has key {
        arena_id: u64,
        creator: address,
        token_metadata: address,
        protocol_treasury: address,
        action_cost: u64,
        timer_buffer_sec: u64,
        max_clicks_per_wallet: u64,

        // Active Round State
        round_id: u64,
        deadline_sec: u64,
        last_leader: address,
        main_pool: u64,
        next_round_fund: u64,
        is_active: bool,

        // O(1) Gas-Optimized Mappings (No historical loops)
        wallet_clicks: Table<address, u64>,
        vault_balances: Table<address, u64>,
    }

    /// Global Factory Registry
    struct FactoryRegistry has key {
        arenas_count: u64,
        protocol_treasury: address,
    }

    #[event]
    struct ArenaCreatedEvent has drop, store {
        arena_id: u64,
        creator: address,
        token_metadata: address,
        action_cost: u64,
    }

    #[event]
    struct ButtonPressedEvent has drop, store {
        arena_id: u64,
        round_id: u64,
        player: address,
        new_deadline_sec: u64,
        burned_amount: u64,
        pool_amount: u64,
    }

    #[event]
    struct RoundFinalizedEvent has drop, store {
        arena_id: u64,
        round_id: u64,
        winner: address,
        reward_amount: u64,
    }

    /// Initialize global factory state
    public entry fun initialize_factory(admin: &signer, treasury: address) {
        let admin_addr = signer::address_of(admin);
        if (!exists<FactoryRegistry>(admin_addr)) {
            move_to(admin, FactoryRegistry {
                arenas_count: 0,
                protocol_treasury: treasury,
            });
        };
    }

    /// Deploy a new custom burn arena for an Aptos Fungible Asset / Coin
    public entry fun create_arena(
        creator: &signer,
        factory_addr: address,
        token_metadata: address,
        action_cost: u64,
        timer_buffer_sec: u64,
        max_clicks_per_wallet: u64
    ) acquires FactoryRegistry {
        assert!(exists<FactoryRegistry>(factory_addr), E_NOT_INITIALIZED);
        let registry = borrow_global_mut<FactoryRegistry>(factory_addr);
        
        registry.arenas_count = registry.arenas_count + 1;
        let new_id = registry.arenas_count;
        let creator_addr = signer::address_of(creator);

        // TODO: Create dedicated Resource Account per arena for multi-instance isolation
        move_to(creator, ArenaConfig {
            arena_id: new_id,
            creator: creator_addr,
            token_metadata,
            protocol_treasury: registry.protocol_treasury,
            action_cost,
            timer_buffer_sec,
            max_clicks_per_wallet,
            round_id: 1,
            deadline_sec: 0,
            last_leader: @0x0,
            main_pool: 0,
            next_round_fund: 0,
            is_active: false,
            wallet_clicks: table::new(),
            vault_balances: table::new(),
        });

        event::emit(ArenaCreatedEvent {
            arena_id: new_id,
            creator: creator_addr,
            token_metadata,
            action_cost,
        });
    }

    /// Core skill-based countdown interaction
    public entry fun press_button(player: &signer, arena_addr: address) acquires ArenaConfig {
        assert!(exists<ArenaConfig>(arena_addr), E_NOT_INITIALIZED);
        let arena = borrow_global_mut<ArenaConfig>(arena_addr);
        let player_addr = signer::address_of(player);
        let now = timestamp::now_seconds();

        // Settle previous round automatically if deadline passed
        if (arena.is_active && now >= arena.deadline_sec) {
            settle_round_internal(arena);
        };

        // Anti-whale per-wallet click check
        let current_clicks = if (table::contains(&arena.wallet_clicks, player_addr)) {
            *table::borrow(&arena.wallet_clicks, player_addr)
        } else {
            0
        };

        if (arena.max_clicks_per_wallet > 0) {
            assert!(current_clicks < arena.max_clicks_per_wallet, E_MAX_CLICKS_REACHED);
        };
        table::upsert(&mut arena.wallet_clicks, player_addr, current_clicks + 1);

        // Tokenomics split: 45% Burn, 44% Active Pool, 10% Next Round, 1% Treasury
        let cost = arena.action_cost;
        let burn_share = (cost * 45) / 100;
        let pool_share = (cost * 44) / 100;
        let next_share = (cost * 10) / 100;
        let _treasury_share = cost - burn_share - pool_share - next_share;

        // TODO: Execute primary_fungible_store::transfer & burn calls here

        arena.main_pool = arena.main_pool + pool_share;
        arena.next_round_fund = arena.next_round_fund + next_share;
        arena.deadline_sec = now + arena.timer_buffer_sec;
        arena.last_leader = player_addr;
        arena.is_active = true;

        event::emit(ButtonPressedEvent {
            arena_id: arena.arena_id,
            round_id: arena.round_id,
            player: player_addr,
            new_deadline_sec: arena.deadline_sec,
            burned_amount: burn_share,
            pool_amount: arena.main_pool,
        });
    }

    /// O(1) constant gas vault withdrawal (no historical loops)
    public entry fun claim_vault(player: &signer, arena_addr: address) acquires ArenaConfig {
        assert!(exists<ArenaConfig>(arena_addr), E_NOT_INITIALIZED);
        let arena = borrow_global_mut<ArenaConfig>(arena_addr);
        let player_addr = signer::address_of(player);

        assert!(table::contains(&arena.vault_balances, player_addr), E_NO_REWARDS_AVAILABLE);
        let reward = *table::borrow(&arena.vault_balances, player_addr);
        assert!(reward > 0, E_NO_REWARDS_AVAILABLE);

        table::upsert(&mut arena.vault_balances, player_addr, 0);
        // TODO: Transfer reward from Arena vault to player_addr
    }

    fun settle_round_internal(arena: &mut ArenaConfig) {
        let winner = arena.last_leader;
        let reward = arena.main_pool;

        let prev_vault = if (table::contains(&arena.vault_balances, winner)) {
            *table::borrow(&arena.vault_balances, winner)
        } else {
            0
        };
        table::upsert(&mut arena.vault_balances, winner, prev_vault + reward);

        event::emit(RoundFinalizedEvent {
            arena_id: arena.arena_id,
            round_id: arena.round_id,
            winner,
            reward_amount: reward,
        });

        arena.round_id = arena.round_id + 1;
        arena.main_pool = arena.next_round_fund;
        arena.next_round_fund = 0;
        arena.is_active = false;
    }
}
