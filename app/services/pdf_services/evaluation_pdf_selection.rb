class PdfServices::EvaluationPdfSelection
  PHASE_SECTIONS = {
    "ProjektPhase::ProposalPhase" => %w[kpis ranking proposals ai_summary key_findings],
    "ProjektPhase::VotingPhase" => %w[kpis questions open_responses key_findings],
    "ProjektPhase::BudgetPhase" => %w[kpis key_findings],
    "ProjektPhase::CommentPhase" => %w[kpis key_findings]
  }.freeze

  ALL_SECTIONS = PHASE_SECTIONS.values.flatten.uniq.freeze

  attr_reader :phase_ids, :sections_by_phase

  def self.all(evaluation)
    phases = evaluation.data["phases"] || []
    phase_ids = phases.map { |p| p["phase_id"].to_i }
    sections_by_phase = phases.each_with_object({}) do |phase, hash|
      hash[phase["phase_id"].to_i] = available_sections(phase["phase_type"])
    end

    new(phase_ids: phase_ids, sections_by_phase: sections_by_phase)
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

    new(phase_ids: phase_ids, sections_by_phase: sections_by_phase)
  end

  def self.available_sections(phase_type)
    PHASE_SECTIONS[phase_type] || []
  end

  def initialize(phase_ids:, sections_by_phase:)
    @phase_ids = phase_ids
    @sections_by_phase = sections_by_phase
  end

  def include_phase?(phase_id)
    phase_ids.include?(phase_id.to_i)
  end

  def include_section?(phase_id, section)
    return false unless include_phase?(phase_id)

    (sections_by_phase[phase_id.to_i] || []).include?(section.to_s)
  end
end
