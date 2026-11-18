module burnbutton::community_voting {
    use std::signer;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};

    const E_ALREADY_VOTED_THIS_EPOCH: u64 = 101;
    const E_VOTING_NOT_INITIALIZED: u64 = 102;

    /// Weekly Community Token Voting State
    struct WeeklyVoting has key {
        current_epoch: u64,
        votes_per_token: Table<address, u64>,
        voter_epoch_record: Table<address, u64>,
    }

    #[event]
    struct VoteCastEvent has drop, store {
        epoch: u64,
        voter: address,
        candidate_token: address,
        new_total_votes: u64,
    }

    public entry fun init_voting(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        if (!exists<WeeklyVoting>(admin_addr)) {
            move_to(admin, WeeklyVoting {
                current_epoch: 1,
                votes_per_token: table::new(),
                voter_epoch_record: table::new(),
            });
        };
    }

    /// Cast 1 wallet = 1 vote for the next weekly featured burn token
    public entry fun vote_for_token(
        voter: &signer,
        voting_addr: address,
        candidate_token: address
    ) acquires WeeklyVoting {
        assert!(exists<WeeklyVoting>(voting_addr), E_VOTING_NOT_INITIALIZED);
        let voting = borrow_global_mut<WeeklyVoting>(voting_addr);
        let voter_addr = signer::address_of(voter);

        if (table::contains(&voting.voter_epoch_record, voter_addr)) {
            let last_epoch = *table::borrow(&voting.voter_epoch_record, voter_addr);
            assert!(last_epoch < voting.current_epoch, E_ALREADY_VOTED_THIS_EPOCH);
        };

        table::upsert(&mut voting.voter_epoch_record, voter_addr, voting.current_epoch);

        let current_votes = if (table::contains(&voting.votes_per_token, candidate_token)) {
            *table::borrow(&voting.votes_per_token, candidate_token)
        } else {
            0
        };
        let updated_votes = current_votes + 1;
        table::upsert(&mut voting.votes_per_token, candidate_token, updated_votes);

        event::emit(VoteCastEvent {
            epoch: voting.current_epoch,
            voter: voter_addr,
            candidate_token,
            new_total_votes: updated_votes,
        });
    }
}
