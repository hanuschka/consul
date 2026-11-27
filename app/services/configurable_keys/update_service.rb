# Writes typed values into key/value setting rows (Setting, ProjektSetting,
# ProjektPhaseSetting). Every key is checked before anything is written, so a
# request with one bad value changes nothing.
class ConfigurableKeys::UpdateService < ApplicationService
  UNKNOWN_KEY_MESSAGE = "is not a configurable key".freeze
  AI_UNAVAILABLE_MESSAGE = "can only be switched on when AI features are available".freeze

  def initialize(changes:, configurable_keys:, setting_rows:)
    @changes = changes.to_h.transform_keys(&:to_s)
    @configurable_keys = configurable_keys
    @setting_rows = setting_rows
  end

  def call
    parsed_values, errors = parse_changes

    if errors.any?
      return ServiceResult.failure(error: :invalid_values, error_details: errors)
    end

    written_rows = write(parsed_values)

    ServiceResult.success(values: stored_values(written_rows))
  rescue ActiveRecord::RecordInvalid => error
    ServiceResult.failure(
      error: :invalid_values,
      error_details: { error.record.key => error.record.errors.full_messages }
    )
  end

  private

    def parse_changes
      errors = {}
      parsed_values = {}

      @changes.each do |key, raw_value|
        configurable_key = @configurable_keys[key]

        if configurable_key.nil?
          errors[key] = [UNKNOWN_KEY_MESSAGE]

          next
        end

        result = configurable_key.parse(raw_value)

        if !result.valid?
          errors[key] = [result.error]
        elsif ai_unavailable_for?(configurable_key, result.value)
          errors[key] = [AI_UNAVAILABLE_MESSAGE]
        else
          parsed_values[key] = result.value
        end
      end

      [parsed_values, errors]
    end

    def ai_unavailable_for?(configurable_key, value)
      configurable_key.ai_gated? && value == true && !Ai::Settings.ai_available?
    end

    def write(parsed_values)
      rows_by_key = @setting_rows.where(key: parsed_values.keys).index_by(&:key)

      ActiveRecord::Base.transaction do
        parsed_values.map do |key, value|
          row = rows_by_key[key] || @setting_rows.create!(key:)
          stored_value = @configurable_keys[key].to_storage(value)

          # An unchanged row is not saved: each save of a projekt setting
          # queues a sync job to the DT overview.
          if row.value != stored_value
            row.update!(value: stored_value)
          end

          row
        end
      end
    ensure
      Current.settings = nil
    end

    def stored_values(written_rows)
      written_rows.to_h do |row|
        [row.key, @configurable_keys[row.key].from_storage(row.value)]
      end
    end
end
