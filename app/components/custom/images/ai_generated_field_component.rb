# frozen_string_literal: true

class Images::AiGeneratedFieldComponent < ApplicationComponent
  LABEL_KEY = "components.images.ai_generated_field_component.label"

  def initialize(form)
    @form = form
  end

  private

    def label_text
      t(LABEL_KEY)
    end
end
