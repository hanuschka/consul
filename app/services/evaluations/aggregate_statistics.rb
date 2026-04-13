class Evaluations::AggregateStatistics < ApplicationService
  PHASE_COLLECTORS = {
    "ProjektPhase::ProposalPhase" => :collect_proposal_stats,
    "ProjektPhase::BudgetPhase" => :collect_budget_stats,
    "ProjektPhase::VotingPhase" => :collect_voting_stats,
    "ProjektPhase::CommentPhase" => :collect_comment_stats
  }.freeze

  def initialize(projekt)
    @projekt = projekt
  end

  def call
    phases_data = collect_all_phases
    totals = aggregate_totals(phases_data)

    {
      totals: totals,
      phases: phases_data
    }
  end

  private

  def collect_all_phases
    @projekt
      .projekt_phases
      .active
      .includes(:projekt)
      .map { |phase| collect_phase_data(phase) }
      .compact
  end

  def collect_phase_data(phase)
    collector_method = PHASE_COLLECTORS[phase.type]
    return nil if collector_method.blank?

    base_data = {
      phase_id: phase.id,
      phase_type: phase.type,
      phase_title: phase.title,
      start_date: phase.start_date&.iso8601,
      end_date: phase.end_date&.iso8601,
      user_status: phase.user_status
    }

    stats = send(collector_method, phase)
    base_data.merge(stats: stats)
  end

  def collect_proposal_stats(phase)
    proposals = phase.resources.base_selection
    supports = ActsAsVotable::Vote.where(
      votable_type: "Proposal",
      votable_id: proposals.select(:id),
      voter_type: "User"
    )
    comments = Comment.where(
      commentable_type: "Proposal",
      commentable_id: proposals.select(:id),
      hidden_at: nil
    )

    top_proposals = proposals
      .order(cached_votes_up: :desc)
      .limit(20)
      .map do |p|
        {
          id: p.id,
          title: p.title,
          description: p.description.to_s.truncate(300),
          supports: p.cached_votes_up + p.officing_bulk_votes
        }
      end

    {
      proposals_count: proposals.count,
      supports_count: supports.count + proposals.sum(:officing_bulk_votes),
      comments_count: comments.count,
      unique_participants: count_proposal_participants(proposals, supports, comments),
      avg_supports_per_proposal: safe_average(
        supports.count + proposals.sum(:officing_bulk_votes),
        proposals.count
      ),
      top_proposals: top_proposals
    }
  end

  def collect_budget_stats(phase)
    return {} if phase.budget.blank?

    investments = phase.budget.investments
    supports = ActsAsVotable::Vote.where(
      votable_type: "Budget::Investment",
      votable_id: investments.select(:id),
      voter_type: "User"
    )

    {
      investments_count: investments.count,
      supports_count: supports.count,
      unique_participants: supports.select(:voter_id).distinct.count,
      total_budget: phase.budget.total_budget
    }
  end

  def collect_voting_stats(phase)
    polls = phase.polls
    return {} if polls.empty?

    poll = polls.first
    voters_count = poll.voters.count

    questions_data = poll.questions.order(:title).map do |question|
      answers_data = question.question_answers.order(:given_order).map do |answer|
        answer_count = answer.total_count

        {
          title: answer.title,
          count: answer_count,
          percentage: safe_percentage(answer_count, voters_count)
        }
      end

      {
        id: question.id,
        title: question.title,
        answers: answers_data,
        total_responses: voters_count
      }
    end

    open_text_count = poll.comments.where(hidden_at: nil).count

    {
      participants_count: voters_count,
      questions_count: poll.questions.count,
      open_text_count: open_text_count,
      questions: questions_data
    }
  end

  def collect_comment_stats(phase)
    comments = phase.comments.where(hidden_at: nil)

    {
      comments_count: comments.count,
      unique_commenters: comments.select(:user_id).distinct.count
    }
  end

  def aggregate_totals(phases_data)
    total_participants = 0
    total_contributions = 0
    total_supports = 0

    phases_data.each do |phase|
      stats = phase[:stats] || {}
      total_participants += stats[:unique_participants].to_i
      total_contributions += stats[:proposals_count].to_i +
                             stats[:investments_count].to_i +
                             stats[:comments_count].to_i +
                             stats[:open_text_count].to_i
      total_supports += stats[:supports_count].to_i
    end

    {
      total_participants: total_participants,
      total_contributions: total_contributions,
      total_supports: total_supports,
      phases_count: phases_data.size
    }
  end

  def count_proposal_participants(proposals, supports, comments)
    author_ids = proposals.select(:author_id).distinct.pluck(:author_id)
    voter_ids = supports.select(:voter_id).distinct.pluck(:voter_id)
    commenter_ids = comments.select(:user_id).distinct.pluck(:user_id)

    (author_ids + voter_ids + commenter_ids).uniq.compact.size
  end

  def safe_average(sum, count)
    return 0.0 if count.zero?

    (sum.to_f / count).round(1)
  end

  def safe_percentage(value, total)
    return 0.0 if total.zero?

    (value.to_f / total * 100).round(1)
  end
end
