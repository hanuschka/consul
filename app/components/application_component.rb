class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
  delegate :kern_button, :form_submit_button, to: :helpers

  include SettingsHelper
  delegate :back_link_to, to: :helpers
  delegate :default_form_builder, to: :controller

  delegate :projekt_phase_feature?, to: :helpers
  delegate :show_admin_controls_for_projekt?, to: :helpers

  def t(key, **options)
    if key.start_with?(".")
      key = "components.#{self.class.name.underscore.tr("/", ".")}#{key}"
    end
    super
  end
end
