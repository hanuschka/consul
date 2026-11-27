require "rails_helper"

describe ProjektPhase::ProposalPhase, "participation" do
  let(:projekt) { create(:projekt) }
  let(:citizen) { create(:user) }
  let(:phase) { create(:proposal_phase, projekt: projekt, active: true, user_status: "registered") }

  def with_setting(phase, key, value)
    phase.settings.find_by!(key: key).update!(value: value)
    ProjektPhase.find(phase.id)
  end

  def administrator
    create(:administrator).user
  end

  def project_manager_of(projekt)
    user = create(:user)
    manager = create(:projekt_manager, user: user)
    create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: ["manage"])
    user
  end

  describe "submitting" do
    it "is open to citizens by default" do
      expect(phase.selectable_by?(citizen)).to be true
    end

    it "is closed to citizens when users may not create proposals" do
      closed = with_setting(phase, "feature.resource.users_can_create_proposals", "")

      expect(closed.selectable_by?(citizen)).to be false
    end

    it "stays open to administrators and project managers when users may not create proposals" do
      closed = with_setting(phase, "feature.resource.users_can_create_proposals", "")

      expect(closed.selectable_by?(administrator)).to be true
      expect(closed.selectable_by?(project_manager_of(projekt))).to be true
    end

    it "is closed once the phase has ended" do
      phase.update!(end_date: 1.day.ago)

      expect(ProjektPhase.find(phase.id).selectable_by?(citizen)).to be false
    end

    it "is closed once the user reached the per-user limit" do
      limited = with_setting(phase, "option.resource.max_submissions_per_user", "1")
      create(:proposal, projekt_phase: limited, author: citizen)

      expect(limited.permission_problem(citizen, location: :new_button_component))
        .to eq(:submissions_limit_exceeded)
    end

    it "applies the per-user limit to guests in guest phases" do
      guest_phase = create(:proposal_phase, projekt: projekt, active: true, user_status: "guest")
      limited = with_setting(guest_phase, "option.resource.max_submissions_per_user", "1")
      guest = create(:user, guest: true, email: "guest-key@example.com")
      create(:proposal, projekt_phase: limited, author: guest)

      expect(limited.permission_problem(guest, location: :new_button_component))
        .to eq(:submissions_limit_exceeded)
    end

    it "lets guests submit in guest phases below the per-user limit" do
      guest_phase = create(:proposal_phase, projekt: projekt, active: true, user_status: "guest")
      limited = with_setting(guest_phase, "option.resource.max_submissions_per_user", "1")
      guest = create(:user, guest: true, email: "guest-key@example.com")

      expect(limited.permission_problem(guest, location: :new_button_component)).to be_nil
    end

    it "has no limit when the per-user limit is empty" do
      create_list(:proposal, 3, projekt_phase: phase, author: citizen)

      expect(phase.permission_problem(citizen, location: :new_button_component)).to be_nil
    end
  end

  describe "supporting" do
    let(:proposal) { create(:proposal, projekt_phase: phase) }

    it "records a support from a citizen who meets the restrictions" do
      expect { proposal.register_vote(citizen, "yes") }.to change { proposal.reload.cached_votes_up }.by(1)
    end

    it "does not record a support once the phase has ended" do
      phase.update!(end_date: 1.day.ago)
      ended_proposal = Proposal.find(proposal.id)

      expect { ended_proposal.register_vote(citizen, "yes") }.not_to change { proposal.reload.cached_votes_up }
    end

    it "lets the user withdraw a support" do
      proposal.register_vote(citizen, "yes")

      proposal.unvote_by(citizen)

      expect(proposal.reload.cached_votes_up).to eq(0)
    end

    context "with a per-user support limit" do
      let(:limited) { with_setting(phase, "option.resource.max_supports_per_user", "1") }

      it "blocks further supports once the limit is reached" do
        create(:proposal, projekt_phase: limited).register_vote(citizen, "yes")

        expect(ProjektPhase.find(limited.id).permission_problem(citizen, location: :votes_component))
          .to eq(:supports_limit_exceeded)
      end

      it "does not apply the limit to agree/disagree voting" do
        up_down = with_setting(limited, "feature.resource.enable_up_and_down_voting", "active")
        create(:proposal, projekt_phase: up_down).register_vote(citizen, "yes")

        expect(up_down.permission_problem(citizen, location: :votes_component)).to be_nil
      end
    end

    context "in a phase for verified users" do
      let(:verified_phase) do
        create(:proposal_phase, projekt: projekt, active: true, user_status: "verified")
      end

      it "does not let unverified users support" do
        expect(verified_phase.votable_by?(citizen)).to be false
      end

      it "lets unverified users support conditionally when conditional voting is on" do
        conditional = with_setting(verified_phase, "feature.resource.conditional_voting", "active")

        expect(conditional.votable_by?(citizen)).to be true
      end
    end
  end

  describe "minimum supports before a proposal is listed" do
    it "hides proposals below the minimum and shows those that reached it" do
      restricted = with_setting(phase, "option.resource.minimum_supports_to_show", "2")
      below = create(:proposal, projekt_phase: restricted, cached_votes_up: 1)
      reached = create(:proposal, projekt_phase: restricted, cached_votes_up: 2)

      expect(Proposal.meets_minimum_supports).to include(reached)
      expect(Proposal.meets_minimum_supports).not_to include(below)
    end

    it "shows every proposal by default" do
      proposal = create(:proposal, projekt_phase: phase, cached_votes_up: 0)

      expect(Proposal.meets_minimum_supports).to include(proposal)
    end
  end

  describe "commenting" do
    it "is allowed for a citizen who meets the restrictions when comments are shown" do
      expect(phase.comments_allowed?(citizen)).to be true
    end

    it "is not allowed when comments are switched off" do
      expect(with_setting(phase, "feature.resource.show_comments", "").comments_allowed?(citizen)).to be false
    end

    it "is not allowed for a user the restrictions exclude" do
      verified_only = create(:proposal_phase, projekt: projekt, active: true, user_status: "verified")

      expect(verified_only.comments_allowed?(citizen)).to be false
    end
  end
end
