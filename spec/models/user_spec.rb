require "rails_helper"

describe User do
  describe "#locale" do
    let(:user) { create(:user) }

    before { user.update_column(:locale, nil) }

    it "falls back to the default locale without changing the record" do
      expect(user.locale).to eq I18n.default_locale.to_s
      expect(user).not_to be_changed
    end

    it "returns the stored locale" do
      user.update_column(:locale, "en")

      expect(user.locale).to eq "en"
    end
  end
end
