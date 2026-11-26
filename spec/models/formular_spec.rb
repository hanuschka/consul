require "rails_helper"

describe Formular do
  let(:phase) { create(:projekt).projekt_phases.create!(type: "ProjektPhase::FormularPhase", active: true) }
  let(:formular) { phase.formular }
  let(:user) { create(:user) }

  def set_limit(value)
    phase.settings.find_by!(key: "option.general.submissions_limit").update!(value: value)
  end

  describe "#submissions_limit_reached_for?" do
    before { FormularAnswer.create!(formular: formular, submitter: user, answers: { "field" => "answer" }) }

    it "is reached once the user submitted as often as the limit allows" do
      set_limit("1")

      expect(formular.submissions_limit_reached_for?(user)).to be true
    end

    it "is not reached below the limit" do
      set_limit("2")

      expect(formular.submissions_limit_reached_for?(user)).to be false
    end

    ["0", ""].each do |value|
      it "means no limit for #{value.inspect}" do
        set_limit(value)

        expect(formular.submissions_limit_reached_for?(user)).to be false
      end
    end

    it "means no limit when the phase has no limit setting" do
      phase.settings.find_by!(key: "option.general.submissions_limit").destroy!

      expect(Formular.find(formular.id).submissions_limit_reached_for?(user)).to be false
    end
  end
end
