require "rails_helper"

describe Adm::UserPolicy do
  describe "Scope" do
    let(:administrator) { create(:administrator).user }

    def resolved
      Adm::UserPolicy::Scope.new(administrator, User).resolve
    end

    it "includes confirmed accounts" do
      expect(resolved).to include(create(:user))
    end

    it "includes accounts that never confirmed their email" do
      expect(resolved).to include(create(:user, :unconfirmed))
    end

    it "includes hidden accounts" do
      expect(resolved).to include(create(:user, hidden_at: Time.current))
    end

    it "excludes guest accounts" do
      expect(resolved).not_to include(create(:user, guest: true))
    end

    it "excludes erased accounts" do
      erased = create(:user)
      erased.erase("spec")

      expect(resolved).not_to include(erased)
    end
  end
end
