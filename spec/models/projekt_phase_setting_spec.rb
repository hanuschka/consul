require "rails_helper"

describe ProjektPhaseSetting do
  describe "feature.form.restrict_map_features_to_marked_areas" do
    let(:key) { "feature.form.restrict_map_features_to_marked_areas" }

    %i[proposal_phase budget_phase point_of_interest_phase].each do |factory|
      it "is off on a new #{factory}" do
        phase = create(factory)

        expect(phase.settings.find_by!(key: key).value).to eq ""
        expect(phase.feature?("form.restrict_map_features_to_marked_areas")).to be false
      end
    end

    it "is added switched off to an existing phase that does not have it yet" do
      phase = create(:proposal_phase)
      phase.settings.find_by!(key: key).destroy!

      ProjektPhaseSetting.add_new_settings

      expect(phase.settings.find_by!(key: key).value).to eq ""
    end

    it "keeps the value of a phase where it is already switched on" do
      phase = create(:proposal_phase)
      phase.settings.find_by!(key: key).update!(value: "active")

      ProjektPhaseSetting.add_new_settings

      expect(phase.settings.find_by!(key: key).value).to eq "active"
    end
  end
end
