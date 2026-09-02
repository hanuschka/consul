class Adm::Projekts::PollQuestionImports::ListItemComponent < ApplicationComponent
  with_collection_parameter :question_import

  BADGE_STYLES = {
    "pending" => "info",
    "extracting" => "info",
    "processing" => "info",
    "completed" => "success",
    "applied" => "success",
    "stalled" => "warning",
    "failed" => "danger"
  }.freeze

  FILES_TRUNCATE = 72
  ERROR_TRUNCATE = 160

  # The phase arrives from the caller rather than through the record: every row
  # on the page belongs to the same phase, and reading it per row would cost one
  # query per row for URLs that are all built from the same phase.
  def initialize(question_import:, projekt_phase:, created_questions_by_id: {})
    @question_import = question_import
    @projekt_phase = projekt_phase
    @created_questions_by_id = created_questions_by_id
  end

  private

    attr_reader :question_import, :projekt_phase, :created_questions_by_id

    def display_status
      question_import.display_status
    end

    def state_label
      I18n.t("adm.projekts.poll_question_imports.states.#{display_status}")
    end

    def badge_style
      BADGE_STYLES.fetch(display_status, "info")
    end

    def file_names
      @file_names ||= question_import.source_files.map { |file| file.filename.to_s }
    end

    def files_summary
      return I18n.t("adm.projekts.poll_question_imports.list.no_files") if file_names.empty?
      return file_names.first.truncate(FILES_TRUNCATE) if file_names.size == 1

      I18n.t("adm.projekts.poll_question_imports.list.files_summary",
             first: file_names.first.truncate(FILES_TRUNCATE), count: file_names.size - 1)
    end

    def show_all_file_names?
      file_names.size > 1
    end

    def show_url
      helpers.adm_projekts_phase_poll_question_import_path(projekt_phase, question_import)
    end

    def delete_url
      show_url
    end

    def poll_questions_url
      helpers.poll_questions_adm_projekts_phase_path(projekt_phase)
    end

    # A stalled row keeps the spinner off: it is not making progress, and a
    # spinner next to a warning badge says two different things at once.
    def analyzing?
      question_import.analyzing? && !question_import.stalled?
    end

    def stalled?
      question_import.stalled?
    end

    def applied?
      question_import.applied?
    end

    # An applied import counts the questions that still exist rather than the ids
    # it stored, so a question deleted since the import is not promised twice.
    def applied_questions_count
      question_import.created_question_ids.count { |id| created_questions_by_id.key?(id) }
    end

    def generated_questions_count
      question_import.questions_payload.size
    end

    def error_preview
      question_import.error_message.to_s.truncate(ERROR_TRUNCATE)
    end

    def show_error?
      question_import.failed? && error_preview.present?
    end

    def created_label
      helpers.l(question_import.created_at, format: :short)
    end

    def author_name
      question_import.author&.name
    end
end
