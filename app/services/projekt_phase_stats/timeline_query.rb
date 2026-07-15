class ProjektPhaseStats::TimelineQuery < ApplicationService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    {
      submissions: submissions_chart_data,
      comments: comments_chart_data,
      total_submissions: total_submissions,
      total_comments: total_comments
    }
  end

  def submissions_chart_data
    @submissions_data ||= build_timeline_data(resources, :created_at)
  end

  def comments_chart_data
    @comments_data ||= build_timeline_data(comments, :created_at)
  end

  def total_submissions
    @total_submissions ||= resources.count
  end

  def total_comments
    @total_comments ||= comments.count
  end

  private

    def resources
      @resources ||=
        case @projekt_phase
        when ProjektPhase::ProposalPhase
          @projekt_phase.proposals.base_selection
        when ProjektPhase::BudgetPhase
          @projekt_phase.budget&.investments || Budget::Investment.none
        else
          Proposal.none
        end
    end

    def comments
      @comments ||=
        case @projekt_phase
        when ProjektPhase::ProposalPhase
          Comment.where(commentable_type: "Proposal", commentable_id: resources.select(:id))
        when ProjektPhase::BudgetPhase
          Comment.where(commentable_type: "Budget::Investment", commentable_id: resources.select(:id))
        else
          Comment.none
        end
    end

    def build_timeline_data(records, date_field)
      return { labels: [], values: [] } unless records.exists?

      grouped = records.group_by_day(date_field).count

      {
        labels: grouped.keys.map { |date| I18n.l(date, format: "%d %b") },
        values: grouped.values
      }
    end
end
