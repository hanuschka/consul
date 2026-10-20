class CreateMunicipalPlanProcedureSteps < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plan_procedure_steps do |t|
      t.integer :given_order

      t.timestamps
    end

    create_table :municipal_plan_procedure_step_translations do |t|
      t.bigint :municipal_plan_procedure_step_id, null: false
      t.string :locale, null: false
      t.string :name

      t.timestamps
    end

    add_index :municipal_plan_procedure_step_translations, :municipal_plan_procedure_step_id,
      name: "index_mp_procedure_step_translations_on_procedure_step_id"
    add_index :municipal_plan_procedure_step_translations, :locale,
      name: "index_mp_procedure_step_translations_on_locale"

    add_reference :municipal_plans, :procedure_step,
      foreign_key: { to_table: :municipal_plan_procedure_steps }, index: true, null: true
  end
end
