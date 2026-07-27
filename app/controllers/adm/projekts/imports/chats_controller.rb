class Adm::Projekts::Imports::ChatsController < Adm::Projekts::BaseController
  ALLOWED_COMMANDS = %w[regenerate summarize import start_over].freeze
  MAX_AGGREGATE_BYTES = 500.megabytes

  before_action :authorize_create
  before_action :find_projekt_import
  before_action :find_ai_chat, except: [:extract, :show]
  before_action :ensure_ai_chat_for_show!, only: [:show]

  def show
    @messages = @ai_chat.ai_chat_messages.order(created_at: :asc)
    @chat_user = @projekt_import.user
    @chat_user_initials = chat_user_initials(@chat_user)
    @chat_user_image_url = chat_user_image_url(@chat_user)
    @created_projekts = ordered_created_projekts

    @breadcrumbs = [
      { name: t("adm.projekts.home.title"), url: adm_projekts_root_path },
      { name: t("adm.projekts.imports.from_files.new.title"), url: new_adm_projekts_import_path },
      { name: t(".title") }
    ]
  end

  def messages
    after_id = params[:after].to_i
    pending_ids = pending_message_ids
    scope = @ai_chat.ai_chat_messages.order(created_at: :asc)

    new_messages = after_id.positive? ? scope.where("id > ?", after_id) : scope
    refreshed_messages = pending_ids.present? ? scope.where(id: pending_ids) : AiChatMessage.none
    combined = (new_messages.to_a + refreshed_messages.to_a).uniq(&:id)

    render json: {
      ai_chat: {
        running: @ai_chat.running?
      },
      messages: combined.sort_by(&:id).map { |m| serialize_message(m) },
      import: {
        status: @projekt_import.status,
        projekt_id: @projekt_import.projekt_id,
        redirect_path: import_redirect_path,
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

    assistant_message = create_assistant_placeholder(user_message)
    ProjektImports::ChatMessageJob.perform_later(user_message.id)

    render json: {
      status: "queued",
      messages: [serialize_message(user_message), serialize_message(assistant_message)]
    }
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
      if params.key?(:generate_image)
        @projekt_import.update!(generate_image: ActiveModel::Type::Boolean.new.cast(params[:generate_image]))
      end

      ProjektImports::ExecuteImportJob.perform_later(@projekt_import.id)

      render json: { status: "importing" }
    else
      user_message = @ai_chat.ai_chat_messages.create!(
        role: "user",
        content: command_prompt_for(name),
        status: "completed",
        custom_command: name
      )

      assistant_message = create_assistant_placeholder(user_message)
      ProjektImports::ChatMessageJob.perform_later(user_message.id)

      render json: {
        status: "queued",
        messages: [serialize_message(user_message), serialize_message(assistant_message)]
      }
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

  def pending_message_ids
    Array(params[:pending]).map(&:to_i).select(&:positive?)
  end

  def ordered_created_projekts
    ids = @projekt_import.created_projekt_ids
    return [] if ids.blank?

    by_id = Projekt.where(id: ids).index_by(&:id)
    ids.filter_map { |id| by_id[id] }
  end

  def find_projekt_import
    @projekt_import = current_user.projekt_imports.find(params[:import_id])
  end

  def import_redirect_path
    return if @projekt_import.projekt_id.blank?
    return if !@projekt_import.completed?

    projekt_path(@projekt_import.projekt_id)
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

  def chat_user_initials(user)
    return "" if user.blank?

    if user.first_name.present? && user.last_name.present?
      "#{user.first_name.chars.first}#{user.last_name.chars.first}".upcase
    else
      user.first_letter_of_name.to_s
    end
  end

  def chat_user_image_url(user)
    return "" if user.blank?
    return "" unless user.image&.attached?

    url_for(user.image.variant(:popup))
  rescue StandardError
    ""
  end

  def create_assistant_placeholder(user_message)
    @ai_chat.ai_chat_messages.create!(
      role: "assistant",
      status: "scheduled",
      user_message_id: user_message.id,
      content: ""
    )
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
      created_at: message.created_at.iso8601,
      html: render_to_string(
        partial: "adm/projekts/imports/chats/message",
        locals: { message: message, user: @projekt_import.user },
        formats: [:html]
      )
    }
  end
end
