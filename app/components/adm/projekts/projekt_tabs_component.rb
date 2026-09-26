class Adm::Projekts::ProjektTabsComponent < ApplicationComponent
  MANAGE_ONLY_ACTIONS = %w[details visibility projekt_managers map whatsapp].freeze
  ALL_ACTIONS = %w[details visibility projekt_managers map phases images documents evaluation].freeze
  WHATSAPP_ACTION = "whatsapp".freeze

  def initialize(projekt:, current_action: nil)
    @projekt = projekt
    @current_action = current_action
  end

  private

    attr_reader :projekt

    def tabs
      [frontend_tab, *projekt_action_tabs]
    end

    def frontend_tab
      {
        label: I18n.t("adm.projekts.projekts.tabs.frontend_page"),
        url: helpers.projekt_path(projekt),
        icon: "open_in_new",
        data: { turbo: false },
        current: false
      }
    end

    def projekt_action_tabs
      visible_actions.reject { |action| MANAGE_ONLY_ACTIONS.include?(action) && !manage_allowed? }.map do |action|
        {
          label: I18n.t("adm.projekts.projekts.tabs.#{action}"),
          url: helpers.send("#{action}_adm_projekts_projekt_path", projekt),
          current: current_action == action
        }
      end
    end

    def visible_actions
      return ALL_ACTIONS if !::Whatsapp.enabled?

      ALL_ACTIONS + [WHATSAPP_ACTION]
    end

    def manage_allowed?
      @manage_allowed ||= Adm::Projekts::ProjektPolicy.new(helpers.current_user, projekt).update?
    end

    def current_action
      @current_action || helpers.action_name
    end
end
