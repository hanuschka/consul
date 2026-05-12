module Adm
  # Single source of truth for the list of admin sections available to a user.
  #
  # Used by:
  #   - Adm::IconRailComponent (left sidebar nav)
  #   - Adm::HomeController    (dashboard "Verwaltungsbereiche" bento)
  #
  # Each section is a Hash with: :key, :icon (Material Symbol), :path, :section
  # (controller namespace used for "active" highlight in the icon rail).
  #
  # Permissions are intentionally identical to the previous inline logic in
  # IconRailComponent#items — change them in one place from now on.
  class NavigationSections
    def self.for(user:, url_helpers:)
      new(user: user, url_helpers: url_helpers).call
    end

    def initialize(user:, url_helpers:)
      @user = user
      @url_helpers = url_helpers
    end

    def call
      list = []

      if @user.administrator?
        list << section(:administration, "admin_panel_settings", @url_helpers.adm_root_path, "Adm")
      end

      if @user.administrator? || @user.projekt_manager?
        list << section(:projekts, "folder", @url_helpers.adm_projekts_root_path, "Adm::Projekts")
      end

      if @user.administrator? || @user.landing_page_manager?
        list << section(:landing_pages, "web", @url_helpers.adm_landing_pages_root_path, "Adm::LandingPages")
      end

      if @user.administrator? || @user.moderator?
        list << section(:moderation, "shield", @url_helpers.adm_moderation_root_path, "Adm::Moderation")
      end

      if Adm::DeficiencyReports::DeficiencyReportPolicy.new(@user, nil).index?
        list << section(:deficiency_reports, "report_problem",
                        @url_helpers.adm_deficiency_reports_root_path, "Adm::DeficiencyReports")
      end

      if Adm::Ideas::IdeaPolicy.new(@user, nil).index?
        list << section(:ideas, "lightbulb", @url_helpers.adm_ideas_root_path, "Adm::Ideas")
      end

      if @url_helpers.feature?(:budgets) && (@user.administrator? || @user.valuator?)
        list << section(:valuation, "account_balance_wallet",
                        @url_helpers.adm_valuation_root_path, "Adm::Valuation")
      end

      if Adm::Officing::BasePolicy.new(@user, nil).index?
        list << section(:officing, "how_to_vote", @url_helpers.adm_officing_root_path, "Adm::Officing")
      end

      list
    end

    private

      def section(key, icon, path, namespace)
        { key: key.to_s, icon: icon, path: path, section: namespace }
      end
  end
end
