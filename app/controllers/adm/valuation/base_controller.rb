class Adm::Valuation::BaseController < Adm::BaseController
  private

    def adm_header_title
      I18n.t("adm.valuation.title")
    end

    def adm_menu_component
      Adm::Valuation::MenuComponent.new
    end
end
