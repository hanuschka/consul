require "rails_helper"

describe MunicipalPlan::ProcedureStep do
  it "requires a name" do
    step = build(:municipal_plan_procedure_step, name: "")

    expect(step).not_to be_valid
  end

  it "lists the steps in the order set, new ones last" do
    first = create(:municipal_plan_procedure_step)
    second = create(:municipal_plan_procedure_step)
    third = create(:municipal_plan_procedure_step)

    MunicipalPlan::ProcedureStep.order_procedure_steps([third.id, first.id])

    expect(MunicipalPlan::ProcedureStep.all).to eq([third, first, second])
  end

  it "can be deleted while no Vorhaben uses it" do
    step = create(:municipal_plan_procedure_step)

    expect(step).to be_safe_to_destroy
    expect(step.destroy).to be_truthy
    expect(MunicipalPlan::ProcedureStep.exists?(step.id)).to be false
  end

  it "cannot be deleted while a Vorhaben uses it" do
    step = create(:municipal_plan_procedure_step)
    create(:municipal_plan, procedure_step: step)

    expect(step).not_to be_safe_to_destroy
    expect(step.destroy).to be false
    expect(step.errors[:base]).to be_present
    expect(MunicipalPlan::ProcedureStep.exists?(step.id)).to be true
  end
end
