class AddSimilarSearchRecheckStatusToProjektPhases < ActiveRecord::Migration[6.1]
  # The manual re-check of already published contributions runs in the
  # background for as long as the phase has contributions, so the phase has to
  # carry where that run stands -- otherwise the button says nothing and can be
  # pressed again while the first run is still working through the phase.
  def change
    add_column :projekt_phases, :similar_search_recheck_status, :string
    add_column :projekt_phases, :similar_search_recheck_finished_at, :datetime
  end
end
