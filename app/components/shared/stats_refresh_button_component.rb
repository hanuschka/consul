class Shared::StatsRefreshButtonComponent < ApplicationComponent
  attr_reader :refresh_path, :status_path, :section, :button_text, :processing_text, :last_updated_text, :last_updated_at, :processing, :disabled

  def initialize(refresh_path:, status_path: nil, section: nil, button_text: nil, processing_text: nil, last_updated_text: nil, last_updated_at: nil, processing: false, disabled: false)
    @refresh_path = refresh_path
    @status_path = status_path
    @section = section
    @button_text = button_text || "custom.ai_stats.refresh_button"
    @processing_text = processing_text || "custom.ai_stats.processing"
    @last_updated_text = "custom.ai_stats.last_updated"
    @last_updated_at = last_updated_at
    @processing = processing
    @disabled = disabled
  end

  def processing?
    processing
  end

  def disabled?
    disabled
  end
end
