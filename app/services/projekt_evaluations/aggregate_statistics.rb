class ProjektEvaluations::AggregateStatistics < ApplicationService
  PHASE_COLLECTORS = {
    "ProjektPhase::ProposalPhase" => :collect_proposal_stats,
    "ProjektPhase::BudgetPhase" => :collect_budget_stats,
    "ProjektPhase::VotingPhase" => :collect_voting_stats,
    "ProjektPhase::CommentPhase" => :collect_comment_stats
  }.freeze

  BUDGET_SEGMENTS = [
    { key: "accepting",
      metrics: %w[visible_proposals_count proposal_authors_count comments_count reported_proposals_count],
      demographics: true },
    { key: "reviewing",
      metrics: %w[pending_proposals_count approved_proposals_count rejected_proposals_count],
      demographics: false },
    { key: "selecting",
      metrics: %w[unique_supporters_count total_votes_count online_votes_count offline_votes_count],
      demographics: true },
    { key: "publishing_prices",
      metrics: %w[selected_proposals_count not_selected_proposals_count],
      demographics: false },
    { key: "balloting",
      metrics: %w[unique_voters_count total_votes_count weighted_votes_total weighted_votes_online weighted_votes_offline],
      demographics: true },
    { key: "finished",
      metrics: %w[winners_count],
      demographics: true }
  ].freeze

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

  def call_for_phase(phase)
    collect_phase_data(phase)
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
      voter_type: "User",
      conditional: false
    )
    comments = Comment.where(
      commentable_type: "Proposal",
      commentable_id: proposals.select(:id),
      hidden_at: nil
    )

    online_votes = supports.count
    offline_votes = proposals.sum(:officing_bulk_votes)
    total_votes = online_votes + offline_votes

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

    top_proposals = assign_ranks(top_proposals)

    proposals_count = proposals.count

    {
      proposals_count: proposals_count,
      proposal_authors_count: proposals.select(:author_id).distinct.count,
      supports_count: total_votes,
      online_votes_count: online_votes,
      offline_votes_count: offline_votes,
      unique_supporters_count: supports.select(:voter_id).distinct.count,
      comments_count: comments.count,
      unique_participants: count_proposal_participants(proposals, supports, comments),
      avg_supports_per_proposal: safe_average(total_votes, proposals_count),
      top_proposals: top_proposals
    }
  end

  def collect_budget_stats(phase)
    return {} if phase.budget.blank?

    investments = phase.budget.investments
    supports = ActsAsVotable::Vote.where(
      votable_type: "Budget::Investment",
      votable_id: investments.select(:id),
      voter_type: "User",
      conditional: false
    )

    top_investments = investments
      .order(cached_votes_up: :desc)
      .limit(20)
      .map do |investment|
        {
          id: investment.id,
          title: investment.title,
          description: investment.description.to_s.truncate(300),
          supports: investment.cached_votes_up.to_i + investment.physical_votes.to_i,
          winner: investment.winner?,
          selected: investment.selected?
        }
      end

    {
      investments_count: investments.count,
      supports_count: supports.count,
      unique_participants: supports.select(:voter_id).distinct.count,
      heading_price: phase.budget.heading&.price,
      currency_symbol: phase.budget.currency_symbol,
      top_investments: top_investments,
      budget_segments: collect_budget_segments(phase)
    }
  end

  def collect_budget_segments(phase)
    BUDGET_SEGMENTS.map do |segment|
      metrics = segment[:metrics].map do |metric_key|
        { key: metric_key, value: phase.stats["#{segment[:key]}_#{metric_key}"].to_i }
      end

      next nil if metrics.all? { |metric| metric[:value].zero? }

      data = { key: segment[:key], metrics: metrics }

      if segment[:demographics]
        data[:user_segments] =
          ProjektPhaseStats::UserSegmentsQuery.call(phase.segment_stats(segment[:key]))
      end

      data
    end.compact
  end

  def collect_voting_stats(phase)
    polls = phase.polls
    return {} if polls.empty?

    polls_data = polls.map { |poll| collect_single_poll(poll) }

    {
      polls_count: polls_data.size,
      participants_count: polls_data.sum { |p| p[:voters_count] },
      questions_count: polls_data.sum { |p| p[:questions_count] },
      open_text_count: polls_data.sum { |p| p[:open_text_count] },
      polls: polls_data
    }
  end

  def collect_single_poll(poll)
    voters_count = poll.voters.count
    visible_comments = poll.comments.where(hidden_at: nil)

    root_questions = poll.questions
      .root_questions
      .includes(
        :translations, :votation_type, :question_answers,
        nested_questions: [:translations, :votation_type, :question_answers]
      )
      .order(:given_order)
      .to_a

    question_ids = root_questions.flat_map do |question|
      [question.id] + question.nested_questions.map(&:id)
    end

    vote_totals = build_answer_vote_totals(question_ids)
    open_answer_texts = build_open_answer_texts(question_ids, poll.show_open_answer_author_name?)

    questions_data = root_questions.map do |question|
      build_question_data(question, voters_count, vote_totals, open_answer_texts)
    end

    comment_entries = visible_comments
      .order(created_at: :asc)
      .pluck(:id, :body, :created_at)
      .map { |id, body, _created_at| { id: id, body: body.to_s } }

    {
      id: poll.id,
      name: poll.name,
      voters_count: voters_count,
      questions_count: questions_data.sum { |q| q[:nested_questions].present? ? q[:nested_questions].size : 1 },
      open_text_count: comment_entries.size,
      open_text_entries: comment_entries,
      questions: questions_data
    }
  end

  def build_question_data(question, voters_count, vote_totals, open_answer_texts)
    answers_data = question.question_answers.map do |answer|
      answer_count = answer_total_votes(answer, vote_totals)

      data = {
        id: answer.id,
        title: answer.title,
        count: answer_count,
        percentage: safe_percentage(answer_count, voters_count)
      }

      if answer.open_answer?
        data[:open_texts] = open_answer_texts[[question.id, answer.title]] || []
      end

      data
    end

    total_mentions = answers_data.sum { |a| a[:count] }
    vote_type = question.votation_type&.vote_type

    data = {
      id: question.id,
      title: question.title,
      vote_type: vote_type,
      max_votes: question.votation_type&.max_votes,
      answers: answers_data,
      total_responses: voters_count,
      total_mentions: total_mentions,
      average: rating_average(vote_type, answers_data),
      chart_type: detect_chart_type(vote_type, answers_data),
      verdict: detect_verdict(vote_type, answers_data)
    }

    if question.nested_questions.any?
      data[:nested_questions] = question.nested_questions.map do |nested_question|
        build_question_data(nested_question, voters_count, vote_totals, open_answer_texts)
      end
    end

    data
  end

  def build_open_answer_texts(question_ids, show_author_name)
    return {} if question_ids.empty?

    scope = Poll::Answer
      .where(question_id: question_ids)
      .where.not(open_answer_text: [nil, ""])
      .order(created_at: :asc)
    scope = scope.includes(:author) if show_author_name

    scope.group_by { |answer| [answer.question_id, answer.answer] }
      .transform_values do |records|
        records.map do |record|
          {
            text: record.open_answer_text,
            author_name: show_author_name ? record.author&.username : nil,
            created_at: record.created_at&.iso8601
          }
        end
      end
  end

  def build_answer_vote_totals(question_ids)
    return empty_answer_vote_totals if question_ids.empty?

    {
      weighted: Poll::Answer
        .where(question_id: question_ids)
        .group(:question_id, :answer)
        .sum(:answer_weight),
      open_counts: Poll::Answer
        .where(question_id: question_ids)
        .where.not(open_answer_text: [nil, ""])
        .group(:question_id, :answer)
        .count,
      partial_amount: ::Poll::PartialResult
        .where(question_id: question_ids)
        .group(:question_id, :answer)
        .sum(:amount),
      partial_counts: ::Poll::PartialResult
        .where(question_id: question_ids)
        .group(:question_id, :answer)
        .count
    }
  end

  def empty_answer_vote_totals
    { weighted: {}, open_counts: {}, partial_amount: {}, partial_counts: {} }
  end

  def answer_total_votes(answer, vote_totals)
    key = [answer.question_id, answer.title]

    if answer.open_answer?
      (vote_totals[:open_counts][key] || 0) + (vote_totals[:partial_counts][key] || 0)
    else
      (vote_totals[:weighted][key] || 0) + (vote_totals[:partial_amount][key] || 0)
    end
  end

  def rating_average(vote_type, answers)
    return nil if vote_type != "rating_scale"

    total = answers.sum { |a| a[:count].to_i }
    return nil if total.zero?

    weighted_sum = answers.each_with_index.sum do |answer, idx|
      (idx + 1) * answer[:count].to_i
    end

    (weighted_sum.to_f / total).round(2)
  end

  def detect_chart_type(vote_type, answers)
    return "scale" if vote_type == "rating_scale"
    return "multi" if vote_type == "multiple"
    return "bars" if answers.size < 2
    return "stacked" if answers.size == 2

    titles = answers.map { |a| a[:title].to_s.downcase }

    if answers.size == 3 && abstain_option?(titles)
      return "measure"
    end

    if answers.size == 3 && sentiment_like?(titles)
      return "donut"
    end

    "preference"
  end

  def abstain_option?(titles)
    titles.any? { |t| t.match?(/keine\s+angabe|k\.a\.|weiß\s+nicht|enthaltung|no\s+opinion/i) }
  end

  def sentiment_like?(titles)
    positive = titles.any? { |t| t.match?(/\bpositiv|\bpositive\b/i) }
    negative = titles.any? { |t| t.match?(/\bnegativ|\bnegative\b/i) }
    neutral = titles.any? { |t| t.match?(/\bneutral\b/i) }

    positive && negative && neutral
  end

  def detect_verdict(vote_type, answers)
    return nil if vote_type != "unique"
    return nil if answers.size < 2 || answers.size > 3

    ja = answers.find { |a| a[:title].to_s.match?(/\b(ja|yes|dafür|gut)\b/i) }
    nein = answers.find { |a| a[:title].to_s.match?(/\b(nein|no|dagegen|nicht)/i) }
    return nil if ja.nil? || nein.nil?

    ja_pct = ja[:percentage].to_f
    nein_pct = nein[:percentage].to_f

    if ja_pct >= 70
      { key: "clear_yes", color: "positive" }
    elsif ja_pct >= 55
      { key: "majority_yes", color: "positive" }
    elsif ja_pct >= 45
      { key: "slight_no", color: "neutral" }
    elsif nein_pct >= 70
      { key: "clear_no", color: "negative" }
    else
      { key: "majority_no", color: "negative" }
    end
  end

  def collect_comment_stats(phase)
    comments = phase.comments.where(hidden_at: nil)

    top_comments = comments
      .order(:created_at)
      .limit(30)
      .includes(:translations)
      .map { |comment| { id: comment.id, body: comment.body.to_s.truncate(400) } }

    {
      comments_count: comments.count,
      unique_commenters: comments.select(:user_id).distinct.count,
      top_comments: top_comments
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

  def assign_ranks(items)
    sorted = items.sort_by { |item| -item[:supports].to_i }

    prev_supports = nil
    current_rank = 0

    sorted.each_with_index do |item, idx|
      supports = item[:supports].to_i

      if supports != prev_supports
        current_rank = idx + 1
        prev_supports = supports
      end

      item[:rank] = current_rank
    end

    sorted
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
