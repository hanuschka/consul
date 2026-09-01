# frozen_string_literal: true

class Shared::AiImageLabelComponent < ApplicationComponent
  def label_text
    t("components.shared.ai_image_label_component.text")
  end

  def tooltip_text
    t("components.shared.ai_image_label_component.tooltip")
  end
end
