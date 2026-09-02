class ProjektImports::BuildImportSummaryService < ApplicationService
  VOTING_PHASE_TYPE = "ProjektPhase::VotingPhase".freeze

  Summary = Struct.new(
    :title, :subtitle, :starts_on, :ends_on, :categories, :phases,
    :content_block_count, :source_filenames,
    keyword_init: true
  )

  Phase = Struct.new(
    :name, :type_label, :starts_on, :ends_on, :poll_question_count,
    keyword_init: true
  )

  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    data = projekt_import.ai_result

    if data.blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.no_ai_result"))
    end

    ServiceResult.success(summary: build_summary(data))
  end

  private

  def build_summary(data)
    Summary.new(
      title: data["title"],
      subtitle: data["subtitle"],
      starts_on: parse_date(data["projekt_start_date"]),
      ends_on: parse_date(data["projekt_end_date"]),
      categories: Array(data["categories"]),
      phases: Array(data["phases"]).map { |phase| build_phase(phase) },
      content_block_count: Array(data["content_blocks"]).size,
      source_filenames: source_filenames
    )
  end

  def build_phase(phase)
    Phase.new(
      name: phase["name"].presence || type_labels[phase["type"]] || phase["type"],
      type_label: type_labels[phase["type"]],
      starts_on: parse_date(phase["start_date"]),
      ends_on: parse_date(phase["end_date"]),
      poll_question_count: poll_question_count(phase)
    )
  end

  def poll_question_count(phase)
    return nil if phase["type"] != VOTING_PHASE_TYPE

    ProjektImports::Builders::PollBuilder.importable_questions(phase["poll_questions"]).size
  end

  def type_labels
    @type_labels ||= ProjektPhase.type_labels
  end

  def source_filenames
    projekt_import.source_files.includes(:blob).map { |file| file.filename.to_s }
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end
end
