class ApplicationComponent < ViewComponent::Base
  include SettingsHelper
  delegate :back_link_to, to: :helpers
  delegate :default_form_builder, to: :controller

  delegate :projekt_phase_feature?, to: :helpers
end
