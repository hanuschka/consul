class Adm::Projekts::BaseController < Adm::BaseController
  private

    def adm_menu_component
      Adm::Projekts::MenuComponent.new
    end
end
