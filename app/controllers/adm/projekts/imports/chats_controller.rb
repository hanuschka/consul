class Adm::Projekts::Imports::ChatsController < Adm::Projekts::BaseController
  ALLOWED_COMMANDS = %w[regenerate summarize import start_over].freeze
  MAX_AGGREGATE_BYTES = 45.megabytes

  before_action :authorize_create
  before_action :find_projekt_import
  before_action :find_ai_chat, except: [:extract, :show]
  before_action :ensure_ai_chat_for_show!, only: [:show]

  def show
    @messages = @ai_chat.ai_chat_messages.order(created_at: :asc)

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.from_files.new.title"), url: new_adm_projekts_import_path },
      { name: t(".title") }
    ]
  end

  def messages
    after_id = params[:after].to_i
    scope = @ai_chat.ai_chat_messages.order(created_at: :asc)
    scope = scope.where("id > ?", after_id) if after_id.positive?

    render json: {
      ai_chat: {
        running: @ai_chat.running?
      },
      messages: scope.map { |m| serialize_message(m) },
      import: {
        status: @projekt_import.status,
        projekt_id: @projekt_import.projekt_id,
        error: @projekt_import.error_message,
        warnings: @projekt_import.warnings
      }
    }
  end

  def message
    attached_documents = parse_attached_documents(params[:attached_documents])

    if params[:content].to_s.strip.blank? && attached_documents.empty?
      render json: { error: t("adm.projekts.imports.errors.empty_message") },
        status: :unprocessable_entity
      return
    end

    user_message = @ai_chat.ai_chat_messages.create!(
      role: "user",
      content: params[:content].to_s,
      status: "completed",
      attached_documents: attached_documents
    )

    ProjektImports::ChatMessageJob.perform_later(user_message.id)

    render json: { message_id: user_message.id, status: "queued" }
  end

  def command
    name = params[:name].to_s

    if ALLOWED_COMMANDS.exclude?(name)
      render json: { error: t("adm.projekts.imports.errors.unknown_command") },
        status: :unprocessable_entity
      return
    end

    case name
    when "start_over"
      @projekt_import.mark_abandoned!
      render json: { status: "abandoned", redirect_path: new_adm_projekts_import_path }
    when "import"
      ProjektImports::ExecuteImportJob.perform_later(@projekt_import.id)
      render json: { status: "importing" }
    else
      user_message = @ai_chat.ai_chat_messages.create!(
        role: "user",
        content: command_prompt_for(name),
        status: "completed",
        custom_command: name
      )

      ProjektImports::ChatMessageJob.perform_later(user_message.id)

      render json: { status: "queued", message_id: user_message.id }
    end
  end

  def extract
    files = Array(params[:files]).reject(&:blank?)

    if files.empty?
      render json: { error: t("adm.projekts.imports.errors.no_files") },
        status: :unprocessable_entity
      return
    end

    if files.sum { |f| f.size.to_i } > MAX_AGGREGATE_BYTES
      render json: { error: t("adm.projekts.imports.errors.too_large") },
        status: :unprocessable_entity
      return
    end

    documents = files.map { |file| extract_single_file(file) }

    render json: { documents: documents }
  end

  def execute
    ProjektImports::ExecuteImportJob.perform_later(@projekt_import.id)

    render json: { status: "importing" }
  end

  private

  def authorize_create
    authorize [:adm, :projekts, Projekt], :create?
  end

  def find_projekt_import
    @projekt_import = current_user.projekt_imports.find(params[:import_id])
  end

  def find_ai_chat
    @ai_chat = @projekt_import.ai_chat
    return if @ai_chat.present?

    render json: { error: t("adm.projekts.imports.errors.no_chat") }, status: :not_found
  end

  def ensure_ai_chat_for_show!
    @ai_chat = @projekt_import.ai_chat
    return if @ai_chat.present?

    redirect_to adm_projekts_import_path(@projekt_import)
  end

  def parse_attached_documents(raw)
    return [] if raw.blank?

    docs = raw.is_a?(String) ? JSON.parse(raw) : raw
    Array(docs).map { |d| d.slice("name", "filetype", "extracted_text") }
  rescue JSON::ParserError
    []
  end

  def extract_single_file(file)
    ext = File.extname(file.original_filename).delete(".").downcase

    if Adm::Projekts::Imports::FromFilesController::ALLOWED_EXTENSIONS.exclude?(ext)
      return { name: file.original_filename, filetype: ext, error: t("adm.projekts.imports.errors.unsupported_type", filename: file.original_filename) }
    end

    result = DocumentTextExtractor.call(file: file)

    if result.success?
      { name: file.original_filename, filetype: ext, extracted_text: result.data[:text] }
    else
      { name: file.original_filename, filetype: ext, error: result.error[:error] }
    end
  end

  def command_prompt_for(name)
    case name
    when "regenerate"
      t("adm.projekts.imports.command_prompts.regenerate")
    when "summarize"
      t("adm.projekts.imports.command_prompts.summarize")
    end
  end

  def serialize_message(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      status: message.status,
      custom_command: message.custom_command,
      attached_documents: message.attached_documents.map { |d| d.slice("name", "filetype") },
      created_at: message.created_at.iso8601
    }
  end
end
