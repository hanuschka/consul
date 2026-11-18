class ProjektPhase::FormularPhase::UpdateSettingsService < ApplicationService
  SETTING_KEYS = {
    primary_cutoff_date: "option.general.primary_formular_cutoff_date",
    submissions_limit: "option.general.submissions_limit"
  }.freeze

  def initialize(formular_phase, attributes)
    @formular_phase = formular_phase
    @attributes = attributes.to_h.symbolize_keys.slice(*SETTING_KEYS.keys)
  end

  def call
    normalized_values = {}
    errors = []

    @attributes.each do |attribute, value|
      normalized_value = normalize(attribute, value.to_s.strip)

      if normalized_value.nil?
        errors << error_message(attribute)
      else
        normalized_values[attribute] = normalized_value
      end
    end

    return ServiceResult.failure(error: errors) if errors.any?

    save_settings(normalized_values)

    ServiceResult.success
  end

  private

    def normalize(attribute, value)
      case attribute
      when :primary_cutoff_date
        normalize_date(value)
      when :submissions_limit
        normalize_limit(value)
      end
    end

    def normalize_date(value)
      return "" if value.blank?

      Date.iso8601(value).iso8601
    rescue Date::Error
      nil
    end

    def normalize_limit(value)
      limit = Integer(value, 10, exception: false)
      return if limit.nil? || limit < 1

      limit.to_s
    end

    def error_message(attribute)
      case attribute
      when :primary_cutoff_date
        "primary_cutoff_date must be an ISO 8601 date (YYYY-MM-DD) or empty."
      when :submissions_limit
        "submissions_limit must be a positive integer."
      end
    end

    def save_settings(normalized_values)
      ProjektPhaseSetting.transaction do
        normalized_values.each do |attribute, value|
          @formular_phase.settings
            .find_or_initialize_by(key: SETTING_KEYS.fetch(attribute))
            .update!(value: value)
        end
      end
    end
end
