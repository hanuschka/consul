require "rails_helper"

describe Adm::SavedContentBlockPolicy do
  let(:administrator) do
    user = create(:user)
    create(:administrator, user: user)
    user
  end
  let(:citizen) { create(:user) }

  let(:managing_manager) { manager_with(:manage) }
  let(:other_managing_manager) { manager_with(:manage) }
  let(:reviewing_manager) { manager_with(:review) }
  let(:unassigned_manager) do
    user = create(:user)
    create(:projekt_manager, user: user)
    user
  end
  let(:super_manager) do
    user = create(:user)
    create(:projekt_manager, user: user, manage_all_projekts: true)
    user
  end

  let(:internal_block) { create(:saved_content_block) }
  let(:own_block) { create(:saved_content_block, user: managing_manager) }
  let(:foreign_block) { create(:saved_content_block, user: other_managing_manager) }

  def manager_with(permission)
    user = create(:user)
    manager = create(:projekt_manager, user: user)
    create(:projekt_manager_assignment, permission, projekt_manager: manager, projekt: create(:projekt))
    user
  end

  def policy_for(user, record)
    described_class.new(user, record)
  end

  describe "#create?" do
    it "is true for an administrator" do
      expect(policy_for(administrator, SavedContentBlock).create?).to be true
    end

    it "is true for a projekt manager managing a projekt" do
      expect(policy_for(managing_manager, SavedContentBlock).create?).to be true
    end

    it "is true for a projekt manager managing all projekts" do
      expect(policy_for(super_manager, SavedContentBlock).create?).to be true
    end

    it "is false for a projekt manager without the manage permission" do
      expect(policy_for(reviewing_manager, SavedContentBlock).create?).to be false
    end

    it "is false for a projekt manager with no assignment" do
      expect(policy_for(unassigned_manager, SavedContentBlock).create?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, SavedContentBlock).create?).to be false
    end

    it "is false without a user" do
      expect(policy_for(nil, SavedContentBlock).create?).to be false
    end
  end

  describe "#update?" do
    it "is true for an administrator on an internal block" do
      expect(policy_for(administrator, internal_block).update?).to be true
    end

    it "is true for an administrator on another user's block" do
      expect(policy_for(administrator, foreign_block).update?).to be true
    end

    it "is true for a managing projekt manager on an internal block" do
      expect(policy_for(managing_manager, internal_block).update?).to be true
    end

    it "is true for a managing projekt manager on their own block" do
      expect(policy_for(managing_manager, own_block).update?).to be true
    end

    it "is false for a managing projekt manager on another user's block" do
      expect(policy_for(managing_manager, foreign_block).update?).to be false
    end

    it "is false for a projekt manager without the manage permission" do
      expect(policy_for(reviewing_manager, internal_block).update?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, internal_block).update?).to be false
    end
  end

  describe "#destroy?" do
    it "is true for a managing projekt manager on an internal block" do
      expect(policy_for(managing_manager, internal_block).destroy?).to be true
    end

    it "is true for a managing projekt manager on their own block" do
      expect(policy_for(managing_manager, own_block).destroy?).to be true
    end

    it "is false for a managing projekt manager on another user's block" do
      expect(policy_for(managing_manager, foreign_block).destroy?).to be false
    end

    it "is false for a projekt manager without the manage permission" do
      expect(policy_for(reviewing_manager, own_block).destroy?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, own_block).destroy?).to be false
    end
  end
end
