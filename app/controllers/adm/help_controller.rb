module Adm
  class HelpController < Adm::BaseController
    def show
      section_key = params[:adm_section].presence || "administration"

      authorize section_key, policy_class: Adm::HelpPolicy

      return head(:not_found) unless Adm::Handbook.configured?

      @help_url = Adm::Handbook.page_url(params[:page]) || Adm::Handbook.section_url(section_key)
      @breadcrumbs = [
        { name: adm_header_title, icon: Adm::Section::ICONS.fetch(section_key)[:material] },
        { name: t("adm.help.show.title") }
      ]
    end
  end
end
