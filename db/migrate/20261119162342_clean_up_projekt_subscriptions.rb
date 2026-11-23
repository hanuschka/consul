class CleanUpProjektSubscriptions < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM projekt_subscriptions WHERE user_id IS NULL
    SQL

    execute <<~SQL
      DELETE FROM projekt_subscriptions
      WHERE id IN (
        SELECT id FROM (
          SELECT
            id,
            ROW_NUMBER() OVER (
              PARTITION BY user_id, projekt_id
              ORDER BY active DESC, updated_at DESC, id DESC
            ) AS position
          FROM projekt_subscriptions
        ) ranked
        WHERE ranked.position > 1
      )
    SQL

    remove_index :projekt_subscriptions, :user_id
    add_index :projekt_subscriptions, [:user_id, :projekt_id], unique: true
  end

  def down
    remove_index :projekt_subscriptions, [:user_id, :projekt_id]
    add_index :projekt_subscriptions, :user_id
  end
end
