module Adm
  class HomeController < Adm::BaseController
    def show
      authorize [:adm, :home]
      @breadcrumbs = [
        { name: t("adm.menu.items.home"), icon: "home" }
      ]

      # Users — "aktiv" = nicht gelöscht, keine Gäste, bestätigter Account.
      @users_total    = User.actual.count
      @users_new_week = User.actual.where("users.created_at >= ?", 7.days.ago).count

      # Verwaltungsbereiche — same source of truth as the left icon rail.
      # We drop the "administration" entry (self-link onto this very page).
      sections = helpers.adm_sections
      @adm_sections = Adm::SectionVisibility.visible_keys_for(current_user)
        .reject { |key| key == "administration" }
        .map { |key| sections[key].merge(key: key, metric: section_metric(key)) }
    end

    private

      # Returns { count:, key: } for sections where a cheap live metric exists,
      # nil otherwise. The key is the i18n suffix under
      # `adm.home.show.adm_sections.metrics.*` (with one/other pluralization).
      def section_metric(key)
        case key
        when "projekts"
          { count: Projekt.current.regular.count, key: "projekts" }
        when "deficiency_reports"
          { count: DeficiencyReport.not_closed.not_archived.count, key: "deficiency_reports" }
        when "ideas"
          { count: Idea.active.count, key: "ideas" }
        when "officing"
          { count: Poll.current.count, key: "officing" }
        end
      end
  end
end
