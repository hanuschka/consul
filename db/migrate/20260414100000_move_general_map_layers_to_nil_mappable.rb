class MoveGeneralMapLayersToNilMappable < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      UPDATE map_layers
      SET mappable_type = NULL, mappable_id = NULL
      WHERE mappable_type = 'Projekt'
        AND mappable_id IN (
          SELECT id FROM projekts WHERE special = true
        )
    SQL
  end

  def down
    execute <<-SQL
      UPDATE map_layers
      SET mappable_type = 'Projekt',
          mappable_id = (SELECT id FROM projekts WHERE special = true LIMIT 1)
      WHERE mappable_type IS NULL
        AND mappable_id IS NULL
    SQL
  end
end
