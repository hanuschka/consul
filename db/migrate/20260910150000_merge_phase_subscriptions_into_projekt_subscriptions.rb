class MergePhaseSubscriptionsIntoProjektSubscriptions < ActiveRecord::Migration[6.1]
  def up
    activate_projekt_subscriptions_for_phase_subscribers
    convert_phase_subscriber_filters
    convert_legacy_phase_subscriber_groups
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

    def activate_projekt_subscriptions_for_phase_subscribers
      execute <<~SQL
        INSERT INTO projekt_subscriptions (projekt_id, user_id, active, created_at, updated_at)
        SELECT DISTINCT pp.projekt_id, pps.user_id, TRUE, NOW(), NOW()
        FROM projekt_phase_subscriptions pps
        INNER JOIN projekt_phases pp ON pp.id = pps.projekt_phase_id
        INNER JOIN users u ON u.id = pps.user_id
        WHERE pp.projekt_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM projekt_subscriptions ps
            WHERE ps.projekt_id = pp.projekt_id AND ps.user_id = pps.user_id
          )
      SQL

      execute <<~SQL
        UPDATE projekt_subscriptions ps
        SET active = TRUE, updated_at = NOW()
        WHERE ps.active = FALSE
          AND EXISTS (
            SELECT 1
            FROM projekt_phase_subscriptions pps
            INNER JOIN projekt_phases pp ON pp.id = pps.projekt_phase_id
            WHERE pp.projekt_id = ps.projekt_id AND pps.user_id = ps.user_id
          )
      SQL
    end

    def convert_phase_subscriber_filters
      execute <<~SQL
        UPDATE recipient_group_filters rgf
        SET kind = 'projekt_subscribers',
            params = jsonb_build_object('projekt_id', pp.projekt_id::text),
            updated_at = NOW()
        FROM projekt_phases pp
        WHERE rgf.kind = 'phase_subscribers'
          AND (rgf.params ->> 'projekt_phase_id') ~ '^[0-9]+$'
          AND pp.id = (rgf.params ->> 'projekt_phase_id')::bigint
      SQL

      execute <<~SQL
        UPDATE recipient_group_filters
        SET kind = 'projekt_subscribers',
            params = jsonb_build_object('projekt_id', params ->> 'projekt_id'),
            updated_at = NOW()
        WHERE kind = 'phase_subscribers'
          AND (params ->> 'projekt_id') IS NOT NULL
      SQL

      execute <<~SQL
        UPDATE recipient_group_filters
        SET kind = 'projekt_subscribers', params = '{}'::jsonb, updated_at = NOW()
        WHERE kind = 'phase_subscribers'
      SQL
    end

    def convert_legacy_phase_subscriber_groups
      execute <<~SQL
        INSERT INTO recipient_group_filters (recipient_group_id, kind, operator, params, position, created_at, updated_at)
        SELECT rg.id, 'projekt_subscribers', 'include',
               jsonb_build_object('projekt_id', rg.origin_class_object_id), 1, NOW(), NOW()
        FROM recipient_groups rg
        INNER JOIN projekts p ON p.id = rg.origin_class_object_id::bigint
        WHERE rg.access_method = 'any_phase_subscribers_ids'
          AND rg.origin_class_name = 'Projekt'
          AND rg.origin_class_object_id ~ '^[0-9]+$'
          AND NOT EXISTS (SELECT 1 FROM recipient_group_filters f WHERE f.recipient_group_id = rg.id)
      SQL

      execute <<~SQL
        UPDATE recipient_groups
        SET access_method = NULL, origin_class_name = NULL, origin_class_object_id = NULL, updated_at = NOW()
        WHERE access_method = 'any_phase_subscribers_ids'
      SQL
    end
end
