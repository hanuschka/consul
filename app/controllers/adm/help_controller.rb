module Adm
  class HelpController < Adm::BaseController
    def show
      section_key = params[:adm_section].presence || "administration"

      authorize section_key, policy_class: Adm::HelpPolicy

      return head(:not_found) unless Adm::Handbook.configured?

      @help_url = Adm::Handbook.page_url(params[:page]) || Adm::Handbook.section_url(section_key)
      @help_origin = Adm::Handbook.origin
      @title = t(section_key == "administration" ? ".title_community" : ".title_handbook")
    end
  end
end
