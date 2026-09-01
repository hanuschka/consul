class Adm::Projekts::PollQuestionImportsController < Adm::Projekts::BaseController
  MAX_AGGREGATE_BYTES = 500.megabytes
  ALLOWED_EXTENSIONS = %w[pdf docx odt txt md].freeze

  STATUS_FILTERS = %w[in_progress failed finished].freeze

  PER_PAGE = 20

  before_action :find_projekt_phase
  before_action :find_question_import, only: %i[show status apply regenerate destroy]

  def index
    authorize_phase(:index?)

    load_import_lists

    @breadcrumbs = breadcrumbs
  end

  def new
    authorize_phase(:new?)

    @missing_tools = ::ProjektImports::RequiredTools.missing
    @breadcrumbs = breadcrumbs(t("adm.projekts.poll_question_imports.new.title"))
  end

  def create
    authorize_phase(:create?)

    files = Array(params[:files]).reject(&:blank?)
    error = files_error(files)

    if error.present?
      render json: { error: error }, status: :unprocessable_entity

      return
    end

    # Committed as pending before the job is enqueued so the page the admin lands
    # on always renders the polling branch rather than an idle one the poller
    # never starts from.
    @question_import = @projekt_phase.poll_question_imports.create!(
      author: current_user,
      status: "pending"
    )
    files.each { |file| @question_import.source_files.attach(file) }

    ::PollQuestionImports::ExtractAndGenerateJob.perform_later(@question_import.id)

    render json: {
      id: @question_import.id,
      status: @question_import.status,
      import_url: adm_projekts_phase_poll_question_import_path(@projekt_phase, @question_import)
    }
  end

  def show
    authorize [:adm, :projekts, @question_import], :show?

    @questions = @question_import.questions_payload
    @page_title = show_page_title
    @breadcrumbs = breadcrumbs(@page_title)
  end

  def status
    authorize [:adm, :projekts, @question_import], :show?

    # The poller treats "stalled" as terminal and reloads, which is what puts the
    # explanation on screen instead of the spinner running out of attempts.
    render json: { status: @question_import.display_status }
  end

  def apply
    authorize [:adm, :projekts, @question_import], :apply?

    result = ::PollQuestionImports::ApplyService.call(
      question_import: @question_import,
      questions_attributes: questions_attributes
    )

    if result.success?
      flash[:notice] = t("adm.projekts.poll_question_imports.apply.success",
                         count: result.data[:questions].size)

      redirect_to poll_questions_adm_projekts_phase_path(@projekt_phase)
    else
      flash[:error] = result.error

      redirect_to adm_projekts_phase_poll_question_import_path(@projekt_phase, @question_import)
    end
  end

  # Re-runs the model over the text already pulled out of the documents, so a
  # disappointing result costs another AI call rather than another upload.
  def regenerate
    authorize [:adm, :projekts, @question_import], :regenerate?

    @question_import.update!(status: "processing", error_message: nil)
    ::PollQuestionImports::ExtractAndGenerateJob.perform_later(@question_import.id)

    redirect_to adm_projekts_phase_poll_question_import_path(@projekt_phase, @question_import)
  end

  def destroy
    authorize [:adm, :projekts, @question_import], :destroy?

    @question_import.destroy!

    redirect_to adm_projekts_phase_poll_question_imports_path(
      @projekt_phase, status: params[:status].presence
    )
  end

  private

    def find_projekt_phase
      @projekt_phase = ::ProjektPhase.find(params[:phase_id])
    end

    def find_question_import
      @question_import = @projekt_phase.poll_question_imports.find(params[:id])
    end

    # index and new have no record to authorize, so they authorize an unsaved one
    # bound to the phase -- the policy resolves the projekt through it either way.
    def authorize_phase(query)
      authorize [:adm, :projekts, ::PollQuestionImport.new(projekt_phase: @projekt_phase)], query
    end

    def load_import_lists
      imports = policy_scope(
        @projekt_phase.poll_question_imports,
        policy_scope_class: Adm::Projekts::PollQuestionImportPolicy::Scope
      )

      @status_filter = params[:status].presence_in(STATUS_FILTERS)
      @import_counts = counts_by_filter(imports)

      @imports = filtered_imports(imports).for_listing
        .includes(:author)
        .with_attached_source_files
        .page(params[:page]).per(PER_PAGE)
      @created_questions_by_id = created_questions_map(@imports)
    end

    # One grouped count for all three chips rather than one COUNT per chip.
    def counts_by_filter(imports)
      by_status = imports.group(:status).count

      {
        "in_progress" => by_status.values_at(*PollQuestionImport::IN_PROGRESS_STATUSES).compact.sum,
        "failed" => by_status.fetch("failed", 0),
        "finished" => by_status.values_at(*PollQuestionImport::FINISHED_STATUSES).compact.sum
      }
    end

    def filtered_imports(imports)
      case @status_filter
      when "in_progress" then imports.in_progress
      when "failed" then imports.failed
      when "finished" then imports.finished
      else imports
      end
    end

    # One query for every applied import on the page rather than one per row, and
    # a hash rather than a scope so a question deleted since the import still
    # leaves the row renderable.
    def created_questions_map(imports)
      ids = imports.flat_map(&:created_question_ids).compact.uniq
      return {} if ids.empty?

      ::Poll::Question.where(id: ids).index_by(&:id)
    end

    def files_error(files)
      return t("adm.projekts.poll_question_imports.errors.no_files") if files.empty?

      if files.sum { |file| file.size.to_i } > MAX_AGGREGATE_BYTES
        return t("adm.projekts.poll_question_imports.errors.too_large")
      end

      invalid = files.find { |file| !allowed_extension?(file) }
      return if invalid.blank?

      t("adm.projekts.poll_question_imports.errors.unsupported_type", filename: invalid.original_filename)
    end

    def allowed_extension?(file)
      extension = File.extname(file.original_filename).delete(".").downcase

      ALLOWED_EXTENSIONS.include?(extension)
    end

    def questions_attributes
      params.permit(
        questions: [
          :include, :title, :description, :vote_type,
          :min_rating_scale_label, :max_rating_scale_label,
          { answers: [:title, :description] }
        ]
      )[:questions]
    end

    # "Questions found" is only true of the preview itself. While the document is
    # still being read the page announces that instead, and a run that failed or
    # is already applied gets the neutral name -- announcing questions found
    # above a panel saying none were is the kind of detail that reads as broken.
    # The breadcrumb reads from this method too, so the two cannot disagree.
    def show_page_title
      return t("adm.projekts.poll_question_imports.show.title_processing") if analyzing_now?
      return t("adm.projekts.poll_question_imports.show.title") if @questions.any?

      t("adm.projekts.poll_question_imports.show.title_neutral")
    end

    def analyzing_now?
      @question_import.analyzing? && !@question_import.stalled?
    end

    def breadcrumbs(current = nil)
      projekt = @projekt_phase.projekt

      crumbs = [
        { name: projekt.page.title, url: phases_adm_projekts_projekt_path(projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.poll_questions.title"),
          url: poll_questions_adm_projekts_phase_path(@projekt_phase) },
        { name: t("adm.projekts.poll_question_imports.index.title"),
          url: (adm_projekts_phase_poll_question_imports_path(@projekt_phase) if current) }
      ]
      crumbs << { name: current } if current

      crumbs
    end
end
