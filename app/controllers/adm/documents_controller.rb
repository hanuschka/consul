module Adm
  class DocumentsController < Adm::BaseController
    def index
      authorize [:adm, :document]
      skip_policy_scope
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), url: adm_root_path },
        { name: t("adm.menu.items.application") },
        { name: t("adm.menu.items.application_subitems.documents") }
      ]
    end
  end
end
