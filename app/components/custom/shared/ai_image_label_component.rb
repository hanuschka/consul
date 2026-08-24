# frozen_string_literal: true

class Shared::AiImageLabelComponent < ApplicationComponent
  TEXT_KEY = "components.shared.ai_image_label_component.text"

  def label_text
    t(TEXT_KEY)
  end
end
