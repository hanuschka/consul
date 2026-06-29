class Adm::Projekts::Imports::FailureDiagnosticsComponent < ApplicationComponent
  HIDDEN_KEYS = %w[backtrace].freeze

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def render?
    failure_stage.present? || detail_rows.any? || backtrace.any?
  end

  private

  attr_reader :projekt_import

  def failure_stage
    projekt_import.failure_stage
  end

  def failure_stage_label
    return nil if failure_stage.blank?

    I18n.t("adm.projekts.imports.failure_stages.#{failure_stage}", default: failure_stage.humanize)
  end

  def detail_rows
    @detail_rows ||=
      (projekt_import.error_details || {})
        .except(*HIDDEN_KEYS)
        .reject { |_key, value| value.blank? }
        .map { |key, value| [key.to_s.humanize, format_value(value)] }
  end

  def backtrace
    @backtrace ||= Array((projekt_import.error_details || {})["backtrace"])
  end

  def format_value(value)
    return value.join(", ") if value.is_a?(Array)

    value.to_s
  end
end
