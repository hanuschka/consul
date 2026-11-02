require "rails_helper"

describe Adm::ProposalPolicy do
  let(:proposal) { create(:proposal) }
  let(:projekt) { proposal.projekt }

  def policy_for(user)
    Adm::ProposalPolicy.new(user, proposal)
  end

  def scoped_manager(permissions:)
    manager = create(:projekt_manager)
    create(:projekt_manager_assignment, projekt: projekt, projekt_manager: manager, permissions: permissions)
    manager.user
  end

  describe "#toggle_admin_accepted?" do
    it "is true for a projekt manager with 'manage' permission" do
      expect(policy_for(scoped_manager(permissions: ["manage"])).toggle_admin_accepted?).to be true
    end

    it "is true for a projekt manager with only 'approve' permission" do
      expect(policy_for(scoped_manager(permissions: ["approve"])).toggle_admin_accepted?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission" do
      expect(policy_for(scoped_manager(permissions: ["moderate"])).toggle_admin_accepted?).to be false
    end
  end

  describe "#show?" do
    it "is true for a projekt manager with only 'approve' permission" do
      expect(policy_for(scoped_manager(permissions: ["approve"])).show?).to be true
    end
  end

  describe "#hide?" do
    it "is false for a projekt manager with only 'approve' permission" do
      expect(policy_for(scoped_manager(permissions: ["approve"])).hide?).to be false
    end
  end
end
