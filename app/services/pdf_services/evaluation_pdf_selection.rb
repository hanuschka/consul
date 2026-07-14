class PdfServices::EvaluationPdfSelection
  PHASE_SECTIONS = {
    "ProjektPhase::ProposalPhase" => %w[kpis key_metrics phase_summary tone ranking ai_summary timeline label_sentiment user_segments heatmap key_findings topic_clustering semantic_clustering ai_questions],
    "ProjektPhase::VotingPhase" => %w[kpis questions open_responses ai_summary key_findings ai_questions],
    "ProjektPhase::BudgetPhase" => %w[kpis phase_summary tone timeline label_sentiment user_segments budget_segments heatmap key_findings topic_clustering semantic_clustering ai_questions],
    "ProjektPhase::CommentPhase" => %w[kpis phase_summary tone timeline user_segments key_findings ai_questions]
  }.freeze

  PDF_EXCLUDED_SECTIONS = %w[heatmap].freeze

  ALL_SECTIONS = PHASE_SECTIONS.values.flatten.uniq.freeze

  attr_reader :phase_ids, :sections_by_phase, :include_report

  def self.all(evaluation)
    phases = evaluation.phases_data
    phase_ids = phases.map { |p| p["phase_id"].to_i }
    sections_by_phase = phases.each_with_object({}) do |phase, hash|
      hash[phase["phase_id"].to_i] = available_sections(phase["phase_type"])
    end

    new(phase_ids: phase_ids, sections_by_phase: sections_by_phase, include_report: true)
  end

  def self.from_saved_visibilities(evaluation)
    phases = evaluation.phases_data
    phase_ids = phases.map { |p| p["phase_id"].to_i }
    visibilities = visibilities_by_phase_id(phase_ids)
    sections_by_phase = phases.each_with_object({}) do |phase, hash|
      available = available_sections(phase["phase_type"])
      hash[phase["phase_id"].to_i] = visible_section_keys_for(phase["phase_id"], available, visibilities)
    end

    new(phase_ids: phase_ids, sections_by_phase: sections_by_phase, include_report: true)
  end

  def self.visibilities_by_phase_id(phase_ids)
    ProjektPhaseEvaluationVisibility
      .where(projekt_phase_id: phase_ids)
      .index_by(&:projekt_phase_id)
  end

  def self.defaults_for(evaluation:, phase_id:, section_group: nil)
    return all(evaluation) if phase_id.blank?

    phase = evaluation.phases_data.find { |p| p["phase_id"].to_i == phase_id.to_i }
    return all(evaluation) if phase.nil?

    available = available_sections(phase["phase_type"])
    visible = visible_section_keys_for(phase_id, available)
    scoped = filter_by_section_group(visible, section_group)

    new(
      phase_ids: [phase_id.to_i],
      sections_by_phase: { phase_id.to_i => scoped },
      include_report: false
    )
  end

  def self.filter_by_section_group(section_keys, section_group)
    ai_keys = Adm::Projekts::EvaluationHelper::EVALUATION_AI_SECTIONS

    case section_group.to_s
    when "stats"
      section_keys - ai_keys
    when "ai"
      section_keys & ai_keys
    else
      section_keys
    end
  end

  def self.visible_section_keys_for(phase_id, available_keys, visibilities = nil)
    visibility =
      if visibilities
        visibilities[phase_id.to_i]
      else
        ProjektPhaseEvaluationVisibility.find_by(projekt_phase_id: phase_id)
      end

    return available_keys if visibility.nil?

    available_keys & visibility.visible_sections
  end

  def self.from_params(evaluation, raw_params)
    return all(evaluation) if raw_params.blank?

    params_hash = raw_params.respond_to?(:to_unsafe_h) ? raw_params.to_unsafe_h : raw_params.to_h
    params_hash = params_hash.with_indifferent_access

    phase_ids = Array(params_hash[:phase_ids]).map(&:to_i)
    raw_sections = params_hash[:sections] || {}

    sections_by_phase = raw_sections.each_with_object({}) do |(phase_id_key, section_list), hash|
      phase_id = phase_id_key.to_i
      hash[phase_id] = Array(section_list).map(&:to_s) & ALL_SECTIONS
    end

    include_report = ActiveModel::Type::Boolean.new.cast(params_hash[:include_report])

    new(
      phase_ids: phase_ids,
      sections_by_phase: sections_by_phase,
      include_report: include_report
    )
  end

  def self.available_sections(phase_type)
    PHASE_SECTIONS[phase_type] || []
  end

  def self.pdf_available_sections(phase_type)
    available_sections(phase_type) - PDF_EXCLUDED_SECTIONS
  end

  def initialize(phase_ids:, sections_by_phase:, include_report: true)
    @phase_ids = phase_ids
    @sections_by_phase = sections_by_phase
    @include_report = include_report
  end

  def include_phase?(phase_id)
    phase_ids.include?(phase_id.to_i)
  end

  def include_section?(phase_id, section)
    return false unless include_phase?(phase_id)

    (sections_by_phase[phase_id.to_i] || []).include?(section.to_s)
  end

  def include_report?
    @include_report
  end
end
