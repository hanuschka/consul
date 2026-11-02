class Proposals::DashboardProgressChartComponent < ApplicationComponent
  GROUP_BY_OPTIONS = %w[week month].freeze

  attr_reader :proposal
  delegate :daily_selected_class,
           :weekly_selected_class,
           :monthly_selected_class,
           :custom_votes_for_proposal_success,
           to: :helpers

  def initialize(proposal)
    @proposal = proposal
  end

  def render?
    @proposal.published?
  end

  private

    def group_by
      params[:group_by].presence_in(GROUP_BY_OPTIONS)
    end
end
