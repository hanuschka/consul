class Adm::Projekts::BaseController < Adm::BaseController
  private

    def adm_menu_component
      Adm::Projekts::MenuComponent.new
    end

    def adm_header_title
      I18n.t("adm.projekts.title")
    end
end
