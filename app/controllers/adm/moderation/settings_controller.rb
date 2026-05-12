class Adm::Moderation::SettingsController < Adm::Moderation::BaseController
  def show
    authorize [:adm, :moderation, :setting], :show?

    @breadcrumbs = [
      { name: t("adm.moderation.menu.items.settings"), icon: "settings" }
    ]
  end
end
