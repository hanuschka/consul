class SeedBaugbMunicipalPlanProcedureSteps < ActiveRecord::Migration[6.1]
  STEP_NAMES = [
    "1.0 Einleitungsbeschluss",
    "2.0 Frühzeitige Unterrichtung der Öffentlichkeit gem. § 3 Abs. 1 BauGB",
    "3.0 Billigungs- und Auslegungsbeschluss",
    "4.0 Veröffentlichung im Internet gem. § 3 Abs. 2 BauGB",
    "5.0 Abwägungs- und Satzungsbeschluss",
    "6.0 Rechtskraft"
  ].freeze

  def up
    if select_value("SELECT 1 FROM municipal_plan_procedure_steps LIMIT 1")
      say "Verfahrensschritte already exist, nothing created"
      return
    end

    STEP_NAMES.each.with_index(1) do |name, given_order|
      step_id = insert(<<~SQL)
        INSERT INTO municipal_plan_procedure_steps (given_order, created_at, updated_at)
        VALUES (#{given_order}, NOW(), NOW())
      SQL

      insert(<<~SQL)
        INSERT INTO municipal_plan_procedure_step_translations
          (municipal_plan_procedure_step_id, locale, name, created_at, updated_at)
        VALUES (#{step_id}, 'de', #{quote(name)}, NOW(), NOW())
      SQL
    end

    say "created #{STEP_NAMES.size} Verfahrensschritte"
  end

  def down
  end
end
