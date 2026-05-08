class Adm::DownloadPdfButtonComponent < ApplicationComponent
  def initialize(url:, map_location: nil, map_container_id: nil, label: nil, loading_label: nil, success_label: nil, icon: "download")
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

    def link_action
      actions = ["click->pdf-download#begin"]
      actions << "click->map-screenshot#capture" if map_capture_enabled?
      actions.join(" ")
    end

    def link_data
      data = {
        pdf_download_target: "trigger",
        action: link_action,
        turbo: false
      }

      if map_capture_enabled?
        data[:controller] = "map-screenshot"
        data[:map_screenshot_container_value] = map_container_id
      end

      data
    end
end
