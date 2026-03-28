class Adm::Valuation::BaseController < Adm::BaseController
  private

    def adm_menu_component
      Adm::Valuation::MenuComponent.new
    end
end
