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

  describe "#recipient_greeting" do
    let(:user) do
      build(:user, username: "maxi84", first_name: "Max", last_name: "Mustermann", gender: "male")
    end

    around { |example| I18n.with_locale(:de) { example.run } }

    def greet_with(option)
      set_setting("email_templates.recipient_greeting", option)
      user.recipient_greeting
    end

    it "greets by username by default" do
      expect(user.recipient_greeting).to eq "Hallo maxi84"
    end

    it "greets by first name" do
      expect(greet_with("first_name")).to eq "Hallo Max"
    end

    it "falls back to the username without a first name" do
      user.first_name = ""

      expect(greet_with("first_name")).to eq "Hallo maxi84"
    end

    it "greets by full name" do
      expect(greet_with("full_name")).to eq "Hallo Max Mustermann"
    end

    it "falls back to the username when a name part is missing" do
      user.last_name = nil

      expect(greet_with("full_name")).to eq "Hallo maxi84"
    end

    describe "formal" do
      it "addresses men and women by last name" do
        expect(greet_with("formal")).to eq "Sehr geehrter Herr Mustermann"

        user.gender = "female"

        expect(user.recipient_greeting).to eq "Sehr geehrte Frau Mustermann"
      end

      it "falls back to the full name without a binary gender" do
        user.gender = "other_gen"

        expect(greet_with("formal")).to eq "Guten Tag Max Mustermann"

        user.gender = nil

        expect(user.recipient_greeting).to eq "Guten Tag Max Mustermann"
      end

      it "falls back to the username without a last name" do
        user.last_name = ""

        expect(greet_with("formal")).to eq "Guten Tag maxi84"
      end
    end
  end
end
