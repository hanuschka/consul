module CustomizableEmail
  extend ActiveSupport::Concern

  private

    def find_custom_template(projekt_phase)
      SiteCustomization::EmailTemplate.find_template(
        projekt_phase,
        self.class.name,
        action_name,
        I18n.locale
      )
    end
end
