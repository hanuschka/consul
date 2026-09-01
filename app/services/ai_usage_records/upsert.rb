class AiUsageRecords::Upsert < ApplicationService
  RETURNED_COLUMNS = (
    %w[period_month feature provider model version] + AiUsageRecord::COUNTER_COLUMNS.map(&:to_s)
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
      columns = @counters.keys
      now = Time.current
      values = [@period_month, @feature, @provider, @model, *@counters.values, 1, now, now]
      placeholders = Array.new(values.size, "?").join(", ")

      increments = columns.map do |column|
        "#{column} = ai_usage_records.#{column} + EXCLUDED.#{column}"
      end

      ActiveRecord::Base.sanitize_sql_array(
        [
          <<~SQL.squish,
            INSERT INTO ai_usage_records
              (period_month, feature, provider, model, #{columns.join(", ")}, version, created_at, updated_at)
            VALUES (#{placeholders})
            ON CONFLICT (period_month, feature, provider, model)
            DO UPDATE SET #{increments.join(", ")},
              version = ai_usage_records.version + 1,
              updated_at = EXCLUDED.updated_at
            RETURNING #{RETURNED_COLUMNS.join(", ")}
          SQL
          *values
        ]
      )
    end
end
