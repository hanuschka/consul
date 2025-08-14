class MoveRelationsInMapLocation < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = proposal_id,
          mappable_type = 'Proposal'
      WHERE proposal_id IS NOT NULL;
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = investment_id,
          mappable_type = 'Budget::Investment'
      WHERE investment_id IS NOT NULL;
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = projekt_id,
          mappable_type = 'Projekt'
      WHERE projekt_id IS NOT NULL;
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = projekt_phase_id,
          mappable_type = 'ProjektPhase'
      WHERE projekt_phase_id IS NOT NULL;
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = deficiency_report_id,
          mappable_type = 'DeficiencyReport'
      WHERE deficiency_report_id IS NOT NULL;
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = registered_address_district_id,
          mappable_type = 'RegisteredAddress::District'
      WHERE registered_address_district_id IS NOT NULL;
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET mappable_id = idea_id,
          mappable_type = 'Idea'
      WHERE idea_id IS NOT NULL;
    SQL

    remove_column :map_locations, :proposal_id
    remove_column :map_locations, :investment_id
    remove_column :map_locations, :projekt_id
    remove_column :map_locations, :projekt_phase_id
    remove_column :map_locations, :deficiency_report_id
    remove_column :map_locations, :registered_address_district_id
    remove_column :map_locations, :idea_id
  end

  def down
    add_column :map_locations, :proposal_id, :integer
    add_column :map_locations, :investment_id, :integer
    add_column :map_locations, :projekt_id, :integer
    add_column :map_locations, :projekt_phase_id, :integer
    add_column :map_locations, :deficiency_report_id, :integer
    add_column :map_locations, :registered_address_district_id, :integer
    add_column :map_locations, :idea_id, :integer

    execute <<-SQL.squish
      UPDATE map_locations
      SET proposal_id = mappable_id
      WHERE mappable_type = 'Proposal';
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET investment_id = mappable_id
      WHERE mappable_type = 'Budget::Investment';
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET projekt_id = mappable_id
      WHERE mappable_type = 'Projekt';
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET projekt_phase_id = mappable_id
      WHERE mappable_type = 'ProjektPhase';
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET deficiency_report_id = mappable_id
      WHERE mappable_type = 'DeficiencyReport';
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET registered_address_district_id = mappable_id
      WHERE mappable_type = 'RegisteredAddress::District';
    SQL

    execute <<-SQL.squish
      UPDATE map_locations
      SET idea_id = mappable_id
      WHERE mappable_type = 'Idea';
    SQL
  end
end
