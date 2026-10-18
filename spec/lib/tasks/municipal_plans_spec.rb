require "rails_helper"

describe "municipal_plans:backfill_legacy_fields" do
  let(:file) { Rails.root.join("spec/fixtures/files/municipal_plans_legacy_export.csv").to_s }
  let(:task) { Rake::Task["municipal_plans:backfill_legacy_fields"] }

  before do
    task.reenable
    allow(ENV).to receive(:[]).and_call_original
  end

  it "fills the imported Vorhaben and prints every outcome, naming the ones to look at" do
    allow(ENV).to receive(:[]).with("FILE").and_return(file)
    steps = (1..6).map { |number| create(:municipal_plan_procedure_step, name: "Schritt #{number}") }
    plan = create(:municipal_plan, legacy_id: "5001")

    expect { task.invoke }.to output(
      a_string_including("rows read: 8\n", "procedure_step_set: 1\n", "procedure_step_not_in_export: 0\n",
                         "untitled: 1\n", "plan_not_found: 6 (5002, 5003, 5004, 5006, 5007, 5008)\n")
    ).to_stdout

    expect(plan.reload.procedure_step).to eq(steps.second)
  end

  it "stops with a message while the setting is on and no Verfahrensschritt is defined" do
    allow(ENV).to receive(:[]).with("FILE").and_return(file)
    set_setting("municipal_plans.procedure_steps", true)

    expect { task.invoke }.to raise_error(SystemExit)
      .and output(/create the Verfahrensschritte first/).to_stderr
  end

  it "insists on the file" do
    allow(ENV).to receive(:[]).with("FILE").and_return(nil)

    expect { task.invoke }.to raise_error(SystemExit).and output(/FILE is required/).to_stderr
  end
end
