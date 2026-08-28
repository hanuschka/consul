class Adm::AiActionButtonComponent < ApplicationComponent
  PROGRESS_MODES = %i[swap inline].freeze
  STYLES = %i[primary secondary].freeze

  def initialize(
    url:,
    text:,
    method: :post,
    icon: "auto_awesome",
    style: :secondary,
    processing_text: nil,
    status_url: nil,
    progress_mode: :swap,
    confirm: nil,
    poll_interval: 4000,
    extra_classes: nil,
    loading: false,
    description: nil,
    compact: false
  )
    @url = url
    @text = text
    @method = method.to_s
    @icon = icon
    @style = STYLES.include?(style) ? style : :secondary
    @processing_text = processing_text.presence || I18n.t("adm.ai_action_button.processing")
    @status_url = status_url
    @progress_mode = PROGRESS_MODES.include?(progress_mode) ? progress_mode : :swap
    @confirm = confirm
    @poll_interval = poll_interval.to_i
    @extra_classes = extra_classes
    @loading = loading
    @description = description
    @compact = compact
  end

  def tooltip_description
    description.presence || I18n.t("adm.ai_action_button.feature_description")
  end

  private

    attr_reader :url, :text, :method, :icon, :style, :processing_text,
                :status_url, :progress_mode, :confirm, :poll_interval,
                :extra_classes, :loading, :description, :compact

    def wrapper_classes
      ["adm-ai-action-button", "-#{progress_mode}", extra_classes].compact_blank.join(" ")
    end

    def button_classes
      classes = ["kern-btn", "kern-btn--#{style}", "adm-ai-action-button--button"]
      classes << "kern-btn--compact" if compact

      classes.join(" ")
    end
end
