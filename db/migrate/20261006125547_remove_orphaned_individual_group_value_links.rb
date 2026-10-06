class RemoveOrphanedIndividualGroupValueLinks < ActiveRecord::Migration[6.1]
  JOIN_TABLES = %w[individual_group_values_projekts individual_group_values_projekt_phases].freeze

  def up
    JOIN_TABLES.each do |table|
      removed = delete(<<~SQL)
        DELETE FROM #{table} links
        WHERE NOT EXISTS (
          SELECT 1 FROM individual_group_values igv WHERE igv.id = links.individual_group_value_id
        )
      SQL

      say "#{table}: removed #{removed} links to deleted group values"
    end
  end

  def down
  end
end
