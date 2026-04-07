class ProjektPhasesQuery < ApplicationQuery
  SEARCHABLE_FIELDS = %i[phase_tab_name].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |scope| apply_search(scope) }
  end

  private

    attr_reader :base_scope, :params

    def searchable_fields
      SEARCHABLE_FIELDS
    end

    def apply_search(scope)
      search_term = searchable_params[:phase_tab_name]
      return scope if search_term.blank?

      scope.left_joins(:translations)
        .where("projekt_phase_translations.locale = :locale OR projekt_phase_translations.locale IS NULL", locale: I18n.locale)
        .where("#{title_sql} ILIKE :term", term: "%#{escape_like(search_term)}%")
    end

    def title_sql
      type_cases = ProjektPhase::PROJEKT_PHASES_TYPES.map do |type|
        human_name = type.constantize.model_name.human.gsub("'", "''")
        "WHEN '#{type}' THEN '#{human_name}'"
      end.join(" ")

      <<~SQL.squish
        COALESCE(
          NULLIF(projekt_phase_translations.phase_tab_name, ''),
          CASE projekt_phases.type #{type_cases} ELSE projekt_phases.type END
        )
      SQL
    end
end
