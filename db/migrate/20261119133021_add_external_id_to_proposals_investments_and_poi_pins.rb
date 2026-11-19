class AddExternalIdToProposalsInvestmentsAndPoiPins < ActiveRecord::Migration[7.2]
  def change
    add_column :proposals, :external_source, :string
    add_column :proposals, :external_id, :string, if_not_exists: true
    add_index(
      :proposals,
      [:projekt_phase_id, :external_source, :external_id],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "index_proposals_on_phase_and_external_id"
    )

    add_column :budget_investments, :external_source, :string
    add_column :budget_investments, :external_id, :string, if_not_exists: true
    add_index(
      :budget_investments,
      [:budget_id, :external_source, :external_id],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "index_budget_investments_on_budget_and_external_id"
    )

    add_column :projekt_point_of_interest_pins, :external_source, :string
    add_column :projekt_point_of_interest_pins, :external_id, :string, if_not_exists: true
    add_index(
      :projekt_point_of_interest_pins,
      [:projekt_phase_id, :external_source, :external_id],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "index_poi_pins_on_phase_and_external_id"
    )
  end
end
