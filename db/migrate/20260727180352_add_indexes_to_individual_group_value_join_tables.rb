class AddIndexesToIndividualGroupValueJoinTables < ActiveRecord::Migration[6.1]
  def change
    add_index :individual_group_values_projekts,
      [:projekt_id, :individual_group_value_id],
      name: "idx_igv_projekts_on_projekt_id_and_value_id"
    add_index :individual_group_values_projekts,
      [:individual_group_value_id, :projekt_id],
      name: "idx_igv_projekts_on_value_id_and_projekt_id"

    add_index :individual_group_values_projekt_phases,
      [:projekt_phase_id, :individual_group_value_id],
      name: "idx_igv_projekt_phases_on_phase_id_and_value_id"
    add_index :individual_group_values_projekt_phases,
      [:individual_group_value_id, :projekt_phase_id],
      name: "idx_igv_projekt_phases_on_value_id_and_phase_id"
  end
end
