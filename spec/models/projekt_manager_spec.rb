require "rails_helper"

describe ProjektManager do
  let(:projekt) { create(:projekt) }

  describe "#allowed_to?" do
    it "is true for any permission when manage_all_projekts is set, regardless of assignment" do
      manager = create(:projekt_manager, user: create(:user), manage_all_projekts: true)

      expect(manager.allowed_to?("manage", projekt)).to be true
      expect(manager.allowed_to?("review", projekt)).to be true
    end

    it "is true when a matching assignment exists for the projekt" do
      manager = create(:projekt_manager, user: create(:user))
      create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager,
                                          permissions: ["moderate"])

      expect(manager.allowed_to?("moderate", projekt)).to be true
    end

    it "is false when an assignment exists but does not include the requested permission" do
      manager = create(:projekt_manager, user: create(:user))
      create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager,
                                          permissions: ["moderate"])

      expect(manager.allowed_to?("manage", projekt)).to be false
    end

    it "is false when no assignment exists for the projekt at all" do
      manager = create(:projekt_manager, user: create(:user))
      create(:projekt_manager_assignment, projekt: create(:projekt), projekt_manager: manager,
                                          permissions: ["manage"])

      expect(manager.allowed_to?("manage", projekt)).to be false
    end

    it "is false when the projekt is blank" do
      manager = create(:projekt_manager, user: create(:user), manage_all_projekts: false)

      expect(manager.allowed_to?("manage", nil)).to be false
    end

    it "accepts a symbol permission the same as a string" do
      manager = create(:projekt_manager, user: create(:user))
      create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: ["manage"])

      expect(manager.allowed_to?(:manage, projekt)).to be true
    end
  end
end
