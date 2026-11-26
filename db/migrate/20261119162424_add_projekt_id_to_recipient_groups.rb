class AddProjektIdToRecipientGroups < ActiveRecord::Migration[7.2]
  def up
    add_reference :recipient_groups, :projekt,
      foreign_key: { on_delete: :nullify },
      index: { unique: true }

    projekts_with_subscribers.each do |projekt_id, projekt_name|
      create_projekt_subscribers_group(projekt_id, projekt_name)
    end
  end

  def down
    remove_reference :recipient_groups, :projekt, foreign_key: true, index: { unique: true }
  end

  private

    def projekts_with_subscribers
      select_rows(<<~SQL)
        SELECT projekts.id, projekts.name
        FROM projekts
        WHERE EXISTS (
          SELECT 1
          FROM projekt_subscriptions
          WHERE projekt_subscriptions.projekt_id = projekts.id
            AND projekt_subscriptions.active
        )
        ORDER BY projekts.id
      SQL
    end

    def create_projekt_subscribers_group(projekt_id, projekt_name)
      group_name = I18n.t(
        "adm.recipient_groups.projekt_subscribers_group_name",
        title: projekt_name,
        locale: I18n.default_locale
      )

      group_id = select_value(<<~SQL)
        INSERT INTO recipient_groups (name, projekt_id, created_at, updated_at)
        VALUES (#{quote(group_name)}, #{projekt_id.to_i}, NOW(), NOW())
        RETURNING id
      SQL

      execute <<~SQL
        INSERT INTO recipient_group_filters
          (recipient_group_id, position, kind, operator, params, created_at, updated_at)
        VALUES (
          #{group_id.to_i},
          1,
          'projekt_subscribers',
          'include',
          jsonb_build_object('projekt_id', #{quote(projekt_id.to_s)}),
          NOW(),
          NOW()
        )
      SQL
    end
end
