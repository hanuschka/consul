class AddUniqueIndexToUserIndividualGroupValue < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      DELETE FROM user_individual_group_values
      WHERE ctid NOT IN (
        SELECT MIN(ctid)
        FROM user_individual_group_values
        GROUP BY user_id, individual_group_value_id
      );
    SQL

    add_index :user_individual_group_values, [:user_id, :individual_group_value_id], unique: true,
      name: "index_user_ig_values_on_user_id_and_ig_value_id"
  end

  def down
    remove_index :user_individual_group_values, name: "index_user_ig_values_on_user_id_and_ig_value_id"
  end
end
