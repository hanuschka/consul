require "rails_helper"
require Rails.root.join("db/migrate/20261019102809_seed_baugb_municipal_plan_procedure_steps")

describe SeedBaugbMunicipalPlanProcedureSteps do
  def migrate
    ActiveRecord::Migration.suppress_messages { SeedBaugbMunicipalPlanProcedureSteps.new.up }
  end

  it "creates the six BauGB steps in order with German names" do
    migrate

    names = Globalize.with_locale(:de) { MunicipalPlan::ProcedureStep.all.map(&:name) }
    expect(names).to eq SeedBaugbMunicipalPlanProcedureSteps::STEP_NAMES
  end

  it "leaves an instance alone that already has steps" do
    existing = create(:municipal_plan_procedure_step, name: "Eigener Schritt")

    migrate

    expect(MunicipalPlan::ProcedureStep.all).to eq [existing]
  end
end
