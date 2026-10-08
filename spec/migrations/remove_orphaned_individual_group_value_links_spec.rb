require "rails_helper"
require Rails.root.join("db/migrate/20261006125547_remove_orphaned_individual_group_value_links")

describe RemoveOrphanedIndividualGroupValueLinks do
  let(:group) { create(:individual_group, kind: "hard") }
  let(:deleted_value) { create(:individual_group_value, individual_group: group) }
  let(:kept_value) { create(:individual_group_value, individual_group: group) }
  let(:projekt) { create(:projekt) }
  let(:projekt_phase) { create(:proposal_phase) }

  def linked_value_ids(table, owner_column, owner_id)
    ActiveRecord::Base.connection.select_values(
      "SELECT individual_group_value_id FROM #{table} WHERE #{owner_column} = #{owner_id}"
    )
  end

  before do
    projekt.individual_group_values << [deleted_value, kept_value]
    projekt_phase.individual_group_values << [deleted_value, kept_value]
    IndividualGroupValue.where(id: deleted_value.id).delete_all
  end

  it "removes links to deleted group values and keeps the others" do
    ActiveRecord::Migration.suppress_messages { RemoveOrphanedIndividualGroupValueLinks.new.up }

    expect(linked_value_ids("individual_group_values_projekts", "projekt_id", projekt.id))
      .to eq [kept_value.id]
    expect(linked_value_ids("individual_group_values_projekt_phases", "projekt_phase_id", projekt_phase.id))
      .to eq [kept_value.id]
  end

  it "leaves an existing projekt restricted to its remaining group" do
    ActiveRecord::Migration.suppress_messages { RemoveOrphanedIndividualGroupValueLinks.new.up }

    expect(Projekt.visible_for(nil)).not_to include(projekt)
  end
end
