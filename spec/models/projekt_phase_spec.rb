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

  describe "#map_features_restricted_to_marked_areas?" do
    let(:phase) { create(:proposal_phase, projekt: projekt) }
    let(:area) do
      {
        "type" => "FeatureCollection",
        "features" => [{
          "type" => "Feature",
          "properties" => {},
          "geometry" => {
            "type" => "Polygon",
            "coordinates" => [[[7.0, 50.8], [7.2, 50.8], [7.2, 51.0], [7.0, 51.0], [7.0, 50.8]]]
          }
        }]
      }
    end

    def switch_on(phase)
      phase.settings.find_by!(key: "feature.form.restrict_map_features_to_marked_areas").update!(value: "active")
    end

    it "is false while the setting is off, even with areas drawn" do
      phase.reload.map_location.update!(features: area)

      expect(phase.reload.map_features_restricted_to_marked_areas?).to be false
    end

    it "is false when the setting is on but no areas are drawn" do
      switch_on(phase)

      expect(phase.reload.map_features_restricted_to_marked_areas?).to be false
    end

    it "is true when the setting is on and areas are drawn" do
      switch_on(phase)
      phase.reload.map_location.update!(features: area)

      expect(phase.reload.map_features_restricted_to_marked_areas?).to be true
    end

    it "does not take areas from the projekt map" do
      switch_on(phase)
      projekt.map_location.update!(features: area)

      expect(phase.reload.map_features_restricted_to_marked_areas?).to be false
    end
  end

  describe "#marked_areas_restrictable?" do
    it "is true for proposal, budget and point-of-interest phases" do
      %i[proposal_phase budget_phase point_of_interest_phase].each do |factory|
        expect(create(factory).marked_areas_restrictable?).to be(true), factory.to_s
      end
    end

    it "is false for other phase types" do
      phase = ProjektPhase.find(create(:projekt_phase, type: "ProjektPhase::DebatePhase").id)

      expect(phase.marked_areas_restrictable?).to be false
    end
  end
end
