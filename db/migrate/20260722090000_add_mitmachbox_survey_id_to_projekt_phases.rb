class AddMitmachboxSurveyIdToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :mitmachbox_survey_id, :string
  end
end
