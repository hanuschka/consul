class Adm::Moderation::BaseController < Adm::BaseController
  private

    def adm_menu_component
      Adm::Moderation::MenuComponent.new
    end

    def adm_header_title
      I18n.t("adm.moderation.title")
    end
end
