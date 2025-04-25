class CreateGraphqlUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :graphql_users do |t|
      t.string :auth_token
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    User.left_outer_joins(:administrator, :projekt_manager)
        .where("administrators.id IS NOT NULL OR projekt_managers.id IS NOT NULL")
        .find_each do |user|
      GraphqlUser.create!(user: user)
    end
  end
end
