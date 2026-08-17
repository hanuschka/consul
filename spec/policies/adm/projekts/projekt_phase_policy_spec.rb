require "rails_helper"

describe Adm::Projekts::ProjektPhasePolicy do
  let(:projekt) { create(:projekt) }
  let(:citizen) { create(:user) }
  let(:projekt_phase) { create(:projekt_phase, projekt: projekt) }

  def policy_for(user, record)
    Adm::Projekts::ProjektPhasePolicy.new(user, record)
  end

  def scoped_manager(permissions:, on:)
    manager_user = create(:user)
    manager = create(:projekt_manager, user: manager_user)
    create(:projekt_manager_assignment, projekt: on, projekt_manager: manager, permissions: permissions)
    manager_user
  end

  # NOTE: per the confirmed Projektwesen test-requirements analysis, `index?`
  # and `show?` on this policy are never actually invoked anywhere in the
  # codebase — the Adm phase list is authorized via
  # `Adm::Projekts::ProjektPolicy#show?` on the parent projekt instead (see
  # `Adm::Projekts::ProjektsController#phases`). These examples document the
  # policy's own logic in isolation; they do not describe reachable
  # application behavior.
  describe "#index?" do
    it "is true for a projekt manager with 'manage' permission on the parent projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt_phase).index?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on the parent projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt_phase).index?).to be false
    end
  end

  describe "#create?" do
    it "is true for a projekt manager with 'manage' permission on the parent projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt).create?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on the parent projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt).create?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, projekt).create?).to be false
    end
  end

  describe "#update?" do
    it "is true for a projekt manager with 'manage' permission on the parent projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt_phase).update?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on the parent projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt_phase).update?).to be false
    end

    it "is false for a projekt manager with only 'create_on_behalf_of' permission on the parent projekt" do
      user = scoped_manager(permissions: ["create_on_behalf_of"], on: projekt)

      expect(policy_for(user, projekt_phase).update?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, projekt_phase).update?).to be false
    end

    # `toggle_active` and `toggle_frontend_visibility`
    # (app/controllers/adm/projekts/phases_controller.rb) are both authorized
    # via `:update?` on this policy — there is no separate policy action for
    # them, so the examples above already cover their access rules.
  end

  describe "#destroy?" do
    it "is true for a projekt manager with 'manage' permission on the parent projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt_phase).destroy?).to be true
    end

    it "is false for a projekt manager with only 'moderate' permission on the parent projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt_phase).destroy?).to be false
    end
  end

  describe "#moderate?" do
    it "is true for a projekt manager with 'manage' permission on the parent projekt" do
      user = scoped_manager(permissions: ["manage"], on: projekt)

      expect(policy_for(user, projekt_phase).moderate?).to be true
    end

    it "is true for a projekt manager with only 'moderate' permission on the parent projekt" do
      user = scoped_manager(permissions: ["moderate"], on: projekt)

      expect(policy_for(user, projekt_phase).moderate?).to be true
    end

    it "is false for a projekt manager with only 'create_on_behalf_of' permission on the parent projekt" do
      user = scoped_manager(permissions: ["create_on_behalf_of"], on: projekt)

      expect(policy_for(user, projekt_phase).moderate?).to be false
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, projekt_phase).moderate?).to be false
    end
  end
end
