class Budgets::PhaseStats::FiltersComponent < ApplicationComponent
  delegate :valid_filters, :current_filter, :link_list, :current_path_with_query_params, to: :helpers

  def render?
    valid_filters&.any?
  end

  private

    def stat_phases
      %w[accepting selecting balloting finished]
    end

    def filters
      stat_phases.map do |phase|
        [
          t("custom.budgets.investments.index.stat_phases.#{phase}"),
          url_to_footer_tab(section: "stats", remote: true, extras: { stats_section: phase }),
          params[:stats_section] == phase,
          remote: true
        ]
      end
    end
end
