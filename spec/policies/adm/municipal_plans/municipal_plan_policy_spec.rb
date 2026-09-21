require "rails_helper"

describe Adm::MunicipalPlans::MunicipalPlanPolicy do
  let(:administrator) do
    user = create(:user)
    create(:administrator, user: user)
    user
  end
  let(:citizen) { create(:user) }

  let(:officer) { create(:municipal_plan_officer) }
  let(:other_officer) { create(:municipal_plan_officer) }
  let(:group) { create(:municipal_plan_officer_group) }

  let(:own_plan) { create(:municipal_plan, responsible: officer) }
  let(:group_plan) { create(:municipal_plan, responsible: group) }
  let(:foreign_plan) { create(:municipal_plan, responsible: other_officer) }

  def policy_for(user, record)
    described_class.new(user, record)
  end

  def scope_for(user)
    described_class::Scope.new(user, MunicipalPlan.all).resolve
  end

  def see_all(value)
    allow(Setting).to receive(:[]).and_call_original
    allow(Setting).to receive(:[]).with("municipal_plans.officers_see_all").and_return(value)
  end

  before { see_all(nil) }

  describe "#index?" do
    it "is true for an administrator" do
      expect(policy_for(administrator, MunicipalPlan).index?).to be true
    end

    it "is true for a case worker" do
      expect(policy_for(officer.user, MunicipalPlan).index?).to be true
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, MunicipalPlan).index?).to be false
    end
  end

  describe "#destroy?" do
    it "is true for an administrator" do
      expect(policy_for(administrator, own_plan).destroy?).to be true
    end

    it "is false for the responsible case worker" do
      expect(policy_for(officer.user, own_plan).destroy?).to be false
    end
  end

  describe "#show? with the setting off" do
    it "is true for the responsible case worker" do
      expect(policy_for(officer.user, own_plan).show?).to be true
    end

    it "is true through the case worker's group" do
      create(:municipal_plan_officer_group_assignment, officer: officer, officer_group: group)

      expect(policy_for(officer.user, group_plan).show?).to be true
    end

    it "is false for another case worker's plan" do
      expect(policy_for(officer.user, foreign_plan).show?).to be false
    end

    it "is true for an administrator" do
      expect(policy_for(administrator, foreign_plan).show?).to be true
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, own_plan).show?).to be false
    end
  end

  describe "#show? with the setting on" do
    before { see_all(true) }

    it "is true for another case worker's plan" do
      expect(policy_for(officer.user, foreign_plan).show?).to be true
    end
  end

  describe "#update?" do
    it "is true for the responsible case worker" do
      expect(policy_for(officer.user, own_plan).update?).to be true
    end

    it "is true through the case worker's group" do
      create(:municipal_plan_officer_group_assignment, officer: officer, officer_group: group)

      expect(policy_for(officer.user, group_plan).update?).to be true
    end

    it "is false for another case worker's plan" do
      expect(policy_for(officer.user, foreign_plan).update?).to be false
    end

    it "stays false for another case worker's plan when the setting is on" do
      see_all(true)

      expect(policy_for(officer.user, foreign_plan).update?).to be false
    end

    it "is true for an administrator" do
      expect(policy_for(administrator, foreign_plan).update?).to be true
    end

    it "is false for a citizen" do
      expect(policy_for(citizen, own_plan).update?).to be false
    end
  end

  describe "Scope with the setting off" do
    it "returns only plans assigned to the case worker or their group" do
      create(:municipal_plan_officer_group_assignment, officer: officer, officer_group: group)
      own_plan
      group_plan
      foreign_plan

      expect(scope_for(officer.user)).to match_array([own_plan, group_plan])
    end

    it "returns nothing for a case worker with no assignments" do
      foreign_plan

      expect(scope_for(officer.user)).to be_empty
    end

    it "returns everything for an administrator" do
      own_plan
      foreign_plan

      expect(scope_for(administrator)).to match_array([own_plan, foreign_plan])
    end

    it "returns nothing for a citizen" do
      own_plan

      expect(scope_for(citizen)).to be_empty
    end
  end

  describe "Scope with the setting on" do
    before { see_all(true) }

    it "returns every plan for a case worker" do
      own_plan
      foreign_plan

      expect(scope_for(officer.user)).to match_array([own_plan, foreign_plan])
    end

    it "still returns nothing for a citizen" do
      own_plan

      expect(scope_for(citizen)).to be_empty
    end
  end
end
