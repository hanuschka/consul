# frozen_string_literal: true

class Images::AiGeneratedFieldComponent < ApplicationComponent
  def initialize(form)
    @form = form
  end

  private

    # The visible label is deliberately terse, so the full sentence carries the
    # meaning through the accessible name and the tooltip.
    def switch_label
      t("components.images.ai_generated_field_component.switch_label")
    end

    def label_text
      t("components.images.ai_generated_field_component.label")
    end

    def tooltip_title
      t("components.images.ai_generated_field_component.tooltip_title")
    end

    def tooltip_text
      t("components.images.ai_generated_field_component.tooltip_text")
    end

    def tooltip_note
      t("components.images.ai_generated_field_component.tooltip_note")
    end

    def field_name
      "#{@form.object_name}[ai_generated]"
    end

    def marked?
      @form.object.ai_generated?
    end
end
