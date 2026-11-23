class MoveProjektPhaseSubscriptionsToProjektSubscriptions < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      INSERT INTO projekt_subscriptions (user_id, projekt_id, active, created_at, updated_at)
      SELECT DISTINCT
        projekt_phase_subscriptions.user_id,
        projekt_phases.projekt_id,
        TRUE,
        NOW(),
        NOW()
      FROM projekt_phase_subscriptions
      INNER JOIN projekt_phases ON projekt_phases.id = projekt_phase_subscriptions.projekt_phase_id
      WHERE projekt_phase_subscriptions.user_id IS NOT NULL
        AND projekt_phases.projekt_id IS NOT NULL
      ON CONFLICT (user_id, projekt_id)
      DO UPDATE SET active = TRUE, updated_at = NOW()
    SQL

    execute <<~SQL
      UPDATE recipient_group_filters AS filters
      SET
        kind = 'projekt_subscribers',
        params = CASE
          WHEN COALESCE(filters.params->>'projekt_id', '') <> '' THEN
            jsonb_build_object('projekt_id', filters.params->>'projekt_id')
          ELSE COALESCE(
            (
              SELECT jsonb_build_object('projekt_id', projekt_phases.projekt_id::text)
              FROM projekt_phases
              WHERE projekt_phases.id::text = filters.params->>'projekt_phase_id'
                AND projekt_phases.projekt_id IS NOT NULL
            ),
            '{}'::jsonb
          )
        END,
        updated_at = NOW()
      WHERE filters.kind = 'phase_subscribers'
    SQL

    execute <<~SQL
      UPDATE recipient_groups
      SET access_method = 'subscriber_ids', updated_at = NOW()
      WHERE access_method = 'any_phase_subscribers_ids'
    SQL
  end

  def down
  end
end
