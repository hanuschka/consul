class Adm::DownloadPdfButtonComponent < ApplicationComponent
  MAP_FALLBACK_DELAY_MS = 8000
  DEFAULT_FALLBACK_DELAY_MS = 800

  def initialize(
    url:,
    map_location: nil,
    map_container_id: nil,
    label: nil,
    loading_label: nil,
    success_label: nil,
    icon: "download"
  )
    @url = url
    @map_location = map_location
    @map_container_id = map_container_id
    @label = label
    @loading_label = loading_label
    @success_label = success_label
    @icon = icon
  end

  private

    attr_reader :url, :map_location, :map_container_id, :icon

    def label
      @label || t(".label")
    end

    def loading_label
      @loading_label || t(".loading")
    end

    def success_label
      @success_label || t(".success")
    end

    def map_capture_enabled?
      map_location.present? && map_container_id.present?
    end

    def fallback_delay_ms
      map_capture_enabled? ? MAP_FALLBACK_DELAY_MS : DEFAULT_FALLBACK_DELAY_MS
    end

    def trigger_action
      actions = ["click->adm--button-with-progress#begin"]
      actions << "click->map-screenshot#capture" if map_capture_enabled?
      actions.join(" ")
    end

    def trigger_data
      data = { action: trigger_action, turbo: false }

      if map_capture_enabled?
        data[:controller] = "map-screenshot"
        data[:map_screenshot_container_value] = map_container_id
      end

      data
    end
end
