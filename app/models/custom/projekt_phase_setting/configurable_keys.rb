# The phase settings the API may write: the keys ProjektPhaseSetting.defaults
# lists for the phase's type, each with the value type /adm edits it as.
module ProjektPhaseSetting::ConfigurableKeys
  DEFAULT_ORDER_KEY = "selectable_setting.general.default_order".freeze

  OPTION_DEFINITIONS = {
    "option.form.description_max_length" => { type: :integer, min: 1 },
    "option.form.map_features_limit" => { type: :integer, min: 0 },
    "option.general.iframe_height" => { type: :integer, min: 0, allow_blank: true },
    "option.general.iframe_width" => { type: :integer, min: 0, allow_blank: true },
    "option.general.iframe_url" => { type: :url, allow_blank: true },
    "option.general.max_number_of_pins_per_user" => { type: :integer, min: 0, allow_blank: true },
    "option.general.newsfeed_id" => { type: :string, allow_blank: true },
    "option.general.newsfeed_type" => { type: :string, allow_blank: true },
    "option.general.primary_formular_cutoff_date" => { type: :date, allow_blank: true },
    "option.general.submissions_limit" => { type: :integer, min: 0 },
    "option.resource.max_submissions_per_user" => { type: :integer, min: 0, allow_blank: true },
    "option.resource.max_supports_per_user" => { type: :integer, min: 0, allow_blank: true },
    "option.resource.minimum_supports_to_show" => { type: :integer, min: 0 },
    "option.resource.votes_for_proposal_success" => { type: :integer, min: 1 }
  }.freeze

  class << self
    def for_phase(projekt_phase)
      phase_default_keys(projekt_phase)
        .filter_map { |key| build(key, projekt_phase) }
        .index_by(&:key)
    end

    private

      def phase_default_keys(projekt_phase)
        ProjektPhaseSetting.defaults.fetch(projekt_phase.class.name, {}).keys.map(&:to_s)
      end

      def build(key, projekt_phase)
        if key.start_with?("feature.")
          ConfigurableKey.new(
            key,
            group: "projekt_phase",
            type: :boolean,
            ai_gated: ProjektPhaseSetting::AI_GATED_KEYS.include?(key)
          )
        elsif OPTION_DEFINITIONS.key?(key)
          ConfigurableKey.new(key, group: "projekt_phase", **OPTION_DEFINITIONS[key])
        elsif key == DEFAULT_ORDER_KEY
          ConfigurableKey.new(
            key, group: "projekt_phase", type: :select, options: default_order_options(projekt_phase)
          )
        end
      end

      def default_order_options(projekt_phase)
        if projekt_phase.is_a?(ProjektPhase::BudgetPhase)
          projekt_phase.investment_orders
        else
          Proposal.proposals_orders
        end
      end
  end
end
