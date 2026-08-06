class ProjektEvaluations::GenerateEvaluation < ApplicationService
  def initialize(projekt, selected_question_ids: [])
    @projekt = projekt
    @selected_question_ids = selected_question_ids
  end

  def call
    preserved_ai_data = capture_preserved_ai_data
    evaluation = find_or_create_evaluation
    evaluation.update!(status: :processing)
    mark_phase_rows_processing(evaluation)

    evaluation.projekt_phase_evaluations.includes(:projekt_phase).each do |row|
      next if row.projekt_phase.blank?

      ProjektEvaluations::GeneratePhaseEvaluation.call(row)
    rescue StandardError => e
      Rails.logger.warn(
        "[Evaluation] Phase generation failed for row ##{row.id}: #{e.message}"
      )
    end

    stats = ProjektEvaluations::AggregateStatistics.call(@projekt)
    ai_available = Ai::Settings.ai_available?
    ai_summary = ai_available ? generate_ai_summary(stats) : preserved_ai_data[:ai_project_summary]
    project_content_summary =
      if ai_available
        generate_project_content_summary
      else
        preserved_ai_data[:project_content_summary]
      end
    selected_questions = collect_selected_questions

    evaluation.update!(
      status: :completed,
      generated_at: Time.current,
      data: {
        totals: stats[:totals],
        ai_project_summary: ai_summary,
        project_content_summary: project_content_summary,
        report_settings: collect_report_settings,
        selected_questions: selected_questions
      },
      selected_question_ids: @selected_question_ids
    )

    evaluation
  rescue StandardError => e
    evaluation&.update(status: :failed)
    evaluation&.projekt_phase_evaluations&.where(status: :processing)&.update_all(status: :failed)
    Rails.logger.error("[Evaluation] Generation failed for Projekt ##{@projekt.id}: #{e.message}")

    raise
  end

  private

  def capture_preserved_ai_data
    data = @projekt.projekt_evaluation&.data || {}

    {
      ai_project_summary: data["ai_project_summary"],
      project_content_summary: data["project_content_summary"]
    }
  end

  def find_or_create_evaluation
    existing = @projekt.projekt_evaluation

    if existing.present?
      existing.update!(status: :pending, data: {})
      return existing
    end

    @projekt.create_projekt_evaluation!(status: :pending)
  end

  def mark_phase_rows_processing(evaluation)
    phase_ids = @projekt
      .projekt_phases
      .active
      .where(type: ProjektEvaluations::AggregateStatistics::PHASE_COLLECTORS.keys)
      .pluck(:id)
    return if phase_ids.blank?

    phase_ids.each do |phase_id|
      row = evaluation.projekt_phase_evaluations.find_or_initialize_by(projekt_phase_id: phase_id)
      row.update!(status: :processing)
    end
  end

  def generate_ai_summary(stats)
    safe_generate("AI summary") { ProjektEvaluations::GenerateAiProjectSummary.call(@projekt, stats) }
  end

  def generate_project_content_summary
    safe_generate("Project content summary") { ProjektEvaluations::GenerateProjectContentSummary.call(@projekt) }
  end

  def safe_generate(label)
    yield
  rescue StandardError => e
    Rails.logger.warn("[Evaluation] #{label} generation failed: #{e.message}")
    nil
  end

  def collect_report_settings
    open_phase_titles = @projekt.projekt_phases.current.map(&:title).compact_blank

    polls_count = @projekt
      .polls
      .joins(:projekt_phase)
      .where(projekt_phases: { active: true })
      .count

    {
      open_phases: open_phase_titles,
      polls_count: polls_count,
      tags: @projekt.tags_list.map(&:name).compact_blank,
      sdg_goals: @projekt.sdg_goals.order(:code).map { |g| { code: g.code.to_i, title: g.title.to_s } }
    }
  end

  def collect_selected_questions
    return [] if @selected_question_ids.blank?

    ProjektPhaseStatQuestion
      .where(id: @selected_question_ids)
      .completed
      .map do |sq|
        {
          id: sq.id,
          phase_id: sq.projekt_phase_id,
          question: sq.question,
          answer: sq.answer
        }
      end
  end
end
