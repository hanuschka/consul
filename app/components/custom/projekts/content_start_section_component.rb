class Projekts::ContentStartSectionComponent < ApplicationComponent
  def initialize(projekt)
    @projekt = projekt
  end

  def render?
    @projekt.present?
  end

  def ai_disabled?
    !Ai::Settings.ai_available?
  end

  def file_import_button_title
    ai_disabled? ? t('ai.disabled_tooltip') : t('custom.projekts.content_start_section.file_import_button.title')
  end

  def prompt_button_title
    ai_disabled? ? t('ai.disabled_tooltip') : t('custom.projekts.content_start_section.prompt_button.title')
  end
end
