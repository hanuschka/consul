class Budgets::PhaseStats::FiltersComponent < ApplicationComponent
  delegate :link_list, to: :helpers

  def initialize(budget)
    @budget = budget
  end

  private

    def stat_phases
      stat_filters = []
      stat_filters << "accepting" if @budget.selecting_or_later?
      stat_filters << "selecting" if @budget.selecting_or_later?
      stat_filters << "balloting" if @budget.balloting_or_later?
      stat_filters << "finished" if @budget.balloting_finished?

      stat_filters
    end

    def filters
      stat_phases.map do |phase|
        [
          t("custom.budgets.investments.index.stat_phases.#{phase}"),
          url_to_footer_tab(section: "stats", remote: true, extras: { stats_section: phase }),
          params[:stats_section] == phase || params[:stats_section].nil? && phase == "finished",
          remote: true
        ]
      end
    end
end
