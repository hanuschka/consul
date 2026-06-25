class Adm::Projekts::BaseController < Adm::BaseController
  private

  # Every controller in this section renders the Projekts sidebar/title/nav —
  # including deeper-nested ones (e.g. Imports) whose Ruby parent namespace
  # (Adm::Projekts::Imports) would otherwise resolve to a missing menu and fall
  # back to the global Adm menu.
  def current_adm_section_namespace
    "Adm::Projekts"
  end
end
