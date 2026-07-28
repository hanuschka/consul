class Adm::ButtonWithProgressComponent < ApplicationComponent
  STYLES = %i[secondary primary].freeze

  def initialize(
    label:,
    loading_label:,
    success_label:,
    url: nil,
    icon: "download",
    success_icon: "check_circle",
    style: :secondary,
    compact: false,
    button_type: "button",
    button_data: {},
    fallback_delay_ms: nil,
    extra_controllers: [],
    extra_root_data: {}
  )
    @label = label
    @loading_label = loading_label
    @success_label = success_label
    @url = url
    @icon = icon
    @success_icon = success_icon
    @style = STYLES.include?(style) ? style : :secondary
    @compact = compact
    @button_type = button_type
    @button_data = button_data || {}
    @fallback_delay_ms = fallback_delay_ms
    @extra_controllers = Array(extra_controllers)
    @extra_root_data = extra_root_data || {}
  end

  private

    attr_reader :label, :loading_label, :success_label, :url, :icon,
                :success_icon, :style, :compact, :button_type, :button_data,
                :fallback_delay_ms, :extra_controllers, :extra_root_data

    def link_mode?
      url.present?
    end

    def root_data
      controllers = (["adm--button-with-progress"] + extra_controllers).join(" ")
      data = { controller: controllers }
      data["adm--button-with-progress-fallback-delay-value"] = fallback_delay_ms if fallback_delay_ms.present?
      data.merge(extra_root_data)
    end

    def trigger_data
      { "adm--button-with-progress-target": "trigger" }.merge(button_data)
    end

    def trigger_class
      "adm-button-with-progress__trigger kern-btn kern-btn--#{style}#{compact_class}"
    end

    def loading_class
      "adm-button-with-progress__loading kern-btn kern-btn--#{style}#{compact_class}"
    end

    def success_class
      "adm-button-with-progress__success kern-btn kern-btn--#{style}#{compact_class}"
    end

    def compact_class
      compact ? " kern-btn--compact" : ""
    end
end
