class AiUsageRecords::Upsert < ApplicationService
  UNIQUE_KEY_COLUMNS = %w[period_month feature provider model].freeze
  RETURNED_COLUMNS = (
    UNIQUE_KEY_COLUMNS + %w[version] + AiUsageRecord::COUNTER_COLUMNS.map(&:to_s)
  ).freeze

  def initialize(period_month:, feature:, provider:, model:, counters:)
    @period_month = period_month
    @feature = feature
    @provider = provider
    @model = model
    @counters = counters.slice(*AiUsageRecord::COUNTER_COLUMNS)
  end

  def call
    return if @counters.empty?

    AiUsageRecord.connection.exec_query(upsert_sql, "AiUsageRecords::Upsert").first
  end

  private

    def upsert_sql
      row = inserted_row
      placeholders = Array.new(row.size, "?").join(", ")

      AiUsageRecord.sanitize_sql_array(
        [
          <<~SQL.squish,
            INSERT INTO #{table_name} (#{column_list(row.keys)})
            VALUES (#{placeholders})
            ON CONFLICT (#{column_list(UNIQUE_KEY_COLUMNS)})
            DO UPDATE SET #{conflict_assignments.join(", ")}
            RETURNING #{column_list(RETURNED_COLUMNS)}
          SQL
          *row.values
        ]
      )
    end

    def inserted_row
      now = Time.current

      {
        period_month: @period_month,
        feature: @feature,
        provider: @provider,
        model: @model,
        **@counters,
        version: 1,
        created_at: now,
        updated_at: now
      }
    end

    def conflict_assignments
      increments = @counters.keys.map do |column|
        counter = quoted(column)

        "#{counter} = #{table_name}.#{counter} + EXCLUDED.#{counter}"
      end

      version = quoted(:version)
      updated_at = quoted(:updated_at)

      [
        *increments,
        "#{version} = #{table_name}.#{version} + 1",
        "#{updated_at} = EXCLUDED.#{updated_at}"
      ]
    end

    def column_list(columns)
      columns.map { |column| quoted(column) }.join(", ")
    end

    def quoted(column)
      AiUsageRecord.connection.quote_column_name(column)
    end

    def table_name
      AiUsageRecord.quoted_table_name
    end
end
