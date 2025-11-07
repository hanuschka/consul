class ApplicationComponent < ViewComponent::Base
  include SettingsHelper
  delegate :back_link_to, to: :helpers
  delegate :default_form_builder, to: :controller

  delegate :projekt_phase_feature?, to: :helpers
  delegate :show_projekt_studio_controls?, to: :helpers

  def t(key, **options)
    if key.start_with?(".")
      key = "components.#{self.class.name.underscore.tr("/", ".")}#{key}"
    end
    super
  end
end
