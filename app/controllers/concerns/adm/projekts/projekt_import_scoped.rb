module Adm::Projekts::ProjektImportScoped
  extend ActiveSupport::Concern

  private

    def visible_projekt_imports
      policy_scope(
        ProjektImport, policy_scope_class: Adm::Projekts::ProjektImportPolicy::Scope
      )
    end
end
