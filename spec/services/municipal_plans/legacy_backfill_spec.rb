require "rails_helper"

describe MunicipalPlans::LegacyBackfill do
  let(:file) { Rails.root.join("spec/fixtures/files/municipal_plans_legacy_export.csv").to_s }
  let(:officer) { create(:municipal_plan_officer) }
  let!(:plans) do
    %w[5001 5002 5003 5004 5006 5007 5008].index_with do |legacy_id|
      create(:municipal_plan, :published, responsible: officer, legacy_id: legacy_id)
    end
  end

  let!(:procedure_steps) do
    (1..6).map { |number| create(:municipal_plan_procedure_step, name: "Schritt #{number}") }
  end

  before { plans["5002"].district_assignments.destroy_all }

  def backfill
    MunicipalPlans::LegacyBackfill.call(file: file)
  end

  it "sets the Verfahrensschritt from the major part of the Versionsnummer" do
    result = backfill

    steps = plans.transform_values { |plan| plan.reload.procedure_step_label }
    expect(steps).to eq("5001" => "Schritt 2", "5002" => "Schritt 1", "5003" => "Schritt 1",
                        "5004" => "Schritt 3", "5006" => nil, "5007" => nil, "5008" => "Schritt 1")
    expect(result.outcomes[:procedure_step_set]).to match_array(%w[5001 5002 5003 5004 5008])
    expect(result.outcomes[:procedure_step_not_in_export]).to match_array(%w[5006 5007])
  end

  it "marks a Vorhaben for the whole city when it has no Ortsteil" do
    result = backfill

    expect(plans["5002"].reload).to be_city_wide
    expect(plans.except("5002").values.map { |plan| plan.reload.city_wide? }).to all(be false)
    expect(result.outcomes[:city_wide_set]).to eq(["5002"])
  end

  it "keeps a Verfahrensschritt that is already set" do
    plans["5001"].update_columns(procedure_step_id: procedure_steps[5].id)

    result = backfill

    expect(plans["5001"].reload.procedure_step).to eq(procedure_steps[5])
    expect(result.outcomes[:procedure_step_already_set]).to eq(["5001"])
  end

  it "leaves a Vorhaben with Ortsteile out of the whole city and names it" do
    plans["5002"].district_assignments.create!(district: create(:registered_address_district))

    result = backfill

    expect(plans["5002"].reload).not_to be_city_wide
    expect(result.outcomes[:city_wide_has_districts]).to eq(["5002"])
    expect(result.outcomes[:city_wide_set]).to be_empty
  end

  it "fills the pending working copy as well, so a release keeps the values" do
    copy = MunicipalPlans::WorkingCopyService.call(plans["5002"])

    result = backfill

    expect(copy.reload.procedure_step).to eq(procedure_steps[0])
    expect(copy).to be_city_wide
    expect(result.outcomes[:working_copy_procedure_step_set]).to eq(["5002"])
    expect(result.outcomes[:working_copy_city_wide_set]).to eq(["5002"])

    copy.update!(submitted_at: Time.current)
    MunicipalPlans::ReleaseService.call(copy)

    expect(plans["5002"].reload.procedure_step).to eq(procedure_steps[0])
    expect(plans["5002"]).to be_city_wide
  end

  it "respects what was set on the working copy by hand" do
    copy = MunicipalPlans::WorkingCopyService.call(plans["5002"])
    copy.update_columns(procedure_step_id: procedure_steps[3].id)
    copy.district_assignments.create!(district: create(:registered_address_district))

    result = backfill

    expect(copy.reload.procedure_step).to eq(procedure_steps[3])
    expect(copy).not_to be_city_wide
    expect(plans["5002"].reload).to be_city_wide
    expect(result.outcomes[:working_copy_procedure_step_already_set]).to eq(["5002"])
    expect(result.outcomes[:working_copy_city_wide_has_districts]).to eq(["5002"])
  end

  it "names the rows the import skipped and the Vorhaben it cannot find" do
    plans["5008"].destroy!

    result = backfill

    expect(result.rows_read).to eq(8)
    expect(result.outcomes[:untitled]).to eq(["5005"])
    expect(result.outcomes[:plan_not_found]).to eq(["5008"])
  end

  it "changes nothing on a second run" do
    backfill
    values = -> { MunicipalPlan.order(:id).pluck(:id, :procedure_step_id, :city_wide, :updated_at) }

    result = nil
    expect { result = backfill }.not_to change(&values)

    %i[procedure_step_set city_wide_set working_copy_procedure_step_set working_copy_city_wide_set]
      .each { |outcome| expect(result.outcomes[outcome]).to be_empty }
    expect(result.outcomes[:procedure_step_already_set]).to match_array(%w[5001 5002 5003 5004 5008])
    expect(result.outcomes[:city_wide_already_set]).to eq(["5002"])
  end

  it "neither advances Versionsnummer or Aktualisierungsdatum nor leaves audits or activity" do
    plans.each_value { |plan| plan.update_columns(content_updated_at: Date.current - 10.days) }
    state = lambda do
      [MunicipalPlan.order(:id).pluck(:version, :content_updated_at, :updated_at),
       Audited::Audit.count, SectionActivity.count]
    end

    expect { backfill }.not_to change(&state)
    expect(plans["5001"].reload.procedure_step).to eq(procedure_steps[1])
  end

  describe "without Verfahrensschritte" do
    before { MunicipalPlan::ProcedureStep.delete_all }

    it "aborts before changing anything while the setting is on" do
      set_setting("municipal_plans.procedure_steps", true)

      expect { backfill }.to raise_error(MunicipalPlans::LegacyImport::MissingProcedureStepsError)
      expect(plans["5002"].reload).not_to be_city_wide
    end

    it "fills only Gesamtes Stadtgebiet while the setting is off" do
      set_setting("municipal_plans.procedure_steps", false)

      result = backfill

      expect(plans["5002"].reload).to be_city_wide
      expect(result.outcomes.select { |outcome, _| outcome.to_s.include?("procedure_step") }.values)
        .to all(be_empty)
    end
  end
end
