require "rails_helper"

describe Adm::Projekts::ProjektPolicy do
  let(:projekt) { create(:projekt) }
  let(:administrator) do
    user = create(:user)
    create(:administrator, user: user)
    user
  end
  let(:citizen) { create(:user) }

  def policy_for(user, record)
    Adm::Projekts::ProjektPolicy.new(user, record)
  end

  def scoped_manager(permissions:, on:)
    manager_user = create(:user)
    manager = create(:projekt_manager, user: manager_user)
    create(:projekt_manager_assignment, projekt: on, projekt_manager: manager, permissions: permissions)
    manager_user
  end

  def super_manager
    manager_user = create(:user)
    create(:projekt_manager, user: manager_user, manage_all_projekts: true)
    manager_user
  end

  describe "#index?" do
    it "is true for an administrator" do
      expect(policy_for(administrator, Projekt).index?).to be true
    end

    it "is true for a super projekt manager" do
      expect(policy_for(super_manager, Projekt).index?).to be true
    end

    it "is true for any projekt manager, even with no assignment on any projekt" do
      manager_user = create(:user)
      create(:projekt_manager, user: manager_user)

      expect(policy_for(manager_user, Projekt).index?).to be true
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, Projekt).index?).to be false
    end
  end

  describe "#create?" do
    it "is true for an administrator" do
      expect(policy_for(administrator, Projekt).create?).to be true
    end

    it "is true for any projekt manager, even with no assignment on any projekt" do
      manager_user = create(:user)
      create(:projekt_manager, user: manager_user)

      expect(policy_for(manager_user, Projekt).create?).to be true
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, Projekt).create?).to be false
    end
  end

  describe "#show?" do
    # CON-2885: `show?` requires `manage` only. `moderate`,
    # `create_on_behalf_of` and `review` each have their own correctly-scoped
    # access path elsewhere — the moderation dashboard, the public "post on
    # behalf of" form, and `Projekt.visible_for` (public frontend preview /
    # notification-recipient list) respectively — and must NOT additionally
    # unlock the admin detail surface that `show?` gates.

    it "is true for an administrator" do
      expect(policy_for(administrator, projekt).show?).to be true
    end

    it "is true for a super projekt manager" do
      expect(policy_for(super_manager, projekt).show?).to be true
    end

    it "is true for a projekt manager with 'manage' permission on this projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt).show?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on this projekt (target behavior)" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt).show?).to be false
    end

    it "is false for a manager with only 'create_on_behalf_of' on this projekt (target behavior)" do
      user = scoped_manager(permissions: ["create_on_behalf_of"], on: projekt)

      expect(policy_for(user, projekt).show?).to be false
    end

    it "is false for a projekt manager with only 'review' permission on this projekt (target behavior)" do
      user = scoped_manager(permissions: ["review"], on: projekt)

      expect(policy_for(user, projekt).show?).to be false
    end

    it "is false for a projekt manager with only 'get_notifications' permission on this projekt" do
      user = scoped_manager(permissions: ["get_notifications"], on: projekt)

      expect(policy_for(user, projekt).show?).to be false
    end

    it "is false for a projekt manager with no assignment on this projekt" do
      user = scoped_manager(permissions: ["manage"], on: create(:projekt))

      expect(policy_for(user, projekt).show?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, projekt).show?).to be false
    end
  end

  describe "#update?" do
    it "is true for an administrator" do
      expect(policy_for(administrator, projekt).update?).to be true
    end

    it "is true for a super projekt manager" do
      expect(policy_for(super_manager, projekt).update?).to be true
    end

    it "is true for a projekt manager with 'manage' permission on this projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt).update?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on this projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt).update?).to be false
    end

    it "is false for a projekt manager with only 'create_on_behalf_of' permission on this projekt" do
      user = scoped_manager(permissions: ["create_on_behalf_of"], on: projekt)

      expect(policy_for(user, projekt).update?).to be false
    end

    it "is false for a projekt manager with only 'review' permission on this projekt" do
      user = scoped_manager(permissions: ["review"], on: projekt)

      expect(policy_for(user, projekt).update?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, projekt).update?).to be false
    end
  end

  describe "#destroy?" do
    it "is true for a projekt manager with 'manage' permission on this projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt).destroy?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on this projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt).destroy?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, projekt).destroy?).to be false
    end
  end
end
