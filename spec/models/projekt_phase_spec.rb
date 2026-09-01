require "rails_helper"

describe ProjektPhase do
  let(:projekt) { create(:projekt) }

  describe "#current? / #expired? / #not_active?" do
    it "is current when active with no date restrictions" do
      phase = create(:projekt_phase, projekt: projekt, active: true)

      expect(phase.current?).to be true
      expect(phase.expired?).to be false
      expect(phase.not_active?).to be false
    end

    it "is not_active when the active flag is not set (factory default)" do
      phase = create(:projekt_phase, projekt: projekt)

      expect(phase.not_active?).to be true
      expect(phase.current?).to be false
    end

    it "is expired once end_date is in the past" do
      phase = create(:projekt_phase, projekt: projekt, active: true, end_date: 1.day.ago)

      expect(phase.expired?).to be true
      expect(phase.current?).to be false
    end
  end

  describe "#permission_problem" do
    def administrator
      user = create(:user)
      create(:administrator, user: user)
      user
    end

    def manager_with_manage(on:)
      user = create(:user)
      manager = create(:projekt_manager, user: user)
      create(:projekt_manager_assignment, projekt: on, projekt_manager: manager, permissions: ["manage"])
      user
    end

    def guest_account_user
      build(:user, guest: true)
    end

    it "returns nil (no problem) for an administrator, even on an inactive/expired phase" do
      phase = create(:projekt_phase, projekt: projekt, active: false, end_date: 1.day.ago)

      expect(phase.permission_problem(administrator)).to be_nil
    end

    it "returns nil for a manager with 'manage' on the parent, bypassing the active/expiry gates" do
      phase = create(:projekt_phase, projekt: projekt, active: false, end_date: 1.day.ago)
      manager_user = manager_with_manage(on: projekt)

      expect(phase.permission_problem(manager_user)).to be_nil
    end

    it "returns :phase_not_active when the phase is not active" do
      phase = create(:projekt_phase, projekt: projekt, active: false)
      citizen = create(:user)

      expect(phase.permission_problem(citizen)).to eq(:phase_not_active)
    end

    it "returns :phase_expired when the phase's end_date has passed" do
      phase = create(:projekt_phase, projekt: projekt, active: true, end_date: 1.day.ago)
      citizen = create(:user)

      expect(phase.permission_problem(citizen)).to eq(:phase_expired)
    end

    it "returns :phase_not_current when the phase has not started yet" do
      phase = create(:projekt_phase, projekt: projekt, active: true, start_date: 1.day.from_now)
      citizen = create(:user)

      expect(phase.permission_problem(citizen)).to eq(:phase_not_current)
    end

    it "skips the expiry check in officing mode when lock_on is still in the future" do
      phase = create(
        :projekt_phase,
        projekt: projekt,
        active: true,
        end_date: 1.day.ago,
        lock_on: 1.day.from_now
      )
      citizen = create(:user)

      expect(phase.permission_problem(citizen, location: :officing)).to be_nil
    end

    it "still enforces :phase_not_active in officing mode (the activation gate is not part of the bypass)" do
      phase = create(
        :projekt_phase,
        projekt: projekt,
        active: false,
        end_date: 1.day.ago,
        lock_on: 1.day.from_now
      )
      citizen = create(:user)

      expect(phase.permission_problem(citizen, location: :officing)).to eq(:phase_not_active)
    end

    it "returns :guest_not_logged_in for a completely anonymous visitor on a guest-status phase" do
      phase = create(:projekt_phase, projekt: projekt, active: true, user_status: "guest")

      expect(phase.permission_problem(nil)).to eq(:guest_not_logged_in)
    end

    it "returns nil (no problem) for a session-guest account on a guest-status phase" do
      phase = create(:projekt_phase, projekt: projekt, active: true, user_status: "guest")

      expect(phase.permission_problem(guest_account_user)).to be_nil
    end

    it "returns :not_logged_in for a completely anonymous visitor on a registered-status phase" do
      phase = create(:projekt_phase, projekt: projekt, active: true, user_status: "registered")

      expect(phase.permission_problem(nil)).to eq(:not_logged_in)
    end

    it "returns :not_logged_in for a session-guest account on a registered-status phase" do
      phase = create(:projekt_phase, projekt: projekt, active: true, user_status: "registered")

      expect(phase.permission_problem(guest_account_user)).to eq(:not_logged_in)
    end

    it "returns :not_verified for a logged-in but unverified citizen on a verified-status phase" do
      phase = create(:projekt_phase, projekt: projekt, active: true, user_status: "verified")
      citizen = create(:user)

      expect(phase.permission_problem(citizen)).to eq(:not_verified)
    end

    it "returns nil (no problem) for a level-three-verified citizen on a verified-status phase" do
      phase = create(:projekt_phase, projekt: projekt, active: true, user_status: "verified")
      verified_citizen = create(:user, :verified)

      expect(phase.permission_problem(verified_citizen)).to be_nil
    end
  end
end
