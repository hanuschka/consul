module ProjektContentBlocksAdminActions
  extend ActiveSupport::Concern
  include AiErrorHandling

  included do
    before_action :set_namespace
    before_action :find_projekt, only: [
      :create, :ai_generate_with_file, :ai_generate_with_prompt, :import_status, :destroy_all,
      :generate_with_ai
    ]
    before_action :find_content_block, only: [
      :destroy, :update, :update_position, :change_with_ai
    ]
    before_action :find_ai_in_progress_content_block, only: [
      :ai_generation_status, :cancel_ai_generation
    ]
  end

  def create
    authorize!(:update, @projekt)

    @content_block = @projekt.content_blocks.build(
      name: "custom",
      body: params[:html],
      key: "projekt_content_block_#{@projekt.id}_#{@projekt.content_blocks.count + 1}_#{DateTime.now.to_i}",
      locale: SiteCustomization::ContentBlock.canonical_locale
    )

    if @content_block.save
      if params[:previous_content_block_id].present?
        @previous_content_block = @projekt.content_blocks.find(params[:previous_content_block_id])
        @content_block.insert_at(@previous_content_block.position + 1)
      else
        @content_block.move_to_top
      end

      render json: { content_block: {id: @content_block.id}, status: { message: I18n.t("custom.projekt_content_blocks.create.success") }}
    else
      render json: { message: I18n.t("custom.projekt_content_blocks.create.error") }
    end
  end

  def update
    authorize!(:update, @content_block.projekt)

    update_params = {}
    update_params[:body] = params[:html] if params.key?(:html)

    if params.key?(:margin_bottom)
      min = SiteCustomization::ContentBlock::MIN_MARGIN_BOTTOM
      update_params[:margin_bottom] = [params[:margin_bottom].to_i, min].max
    end

    if @content_block.update(update_params)
      render json: { status: { message: I18n.t("custom.projekt_content_blocks.update.success") }}
    else
      render json: { message: I18n.t("custom.projekt_content_blocks.update.error") }
    end
  end

  def destroy
    authorize!(:update, @content_block.projekt)

    if @content_block.destroy
      render json: { status: { message: I18n.t("custom.projekt_content_blocks.destroy.success") }}
    else
      render json: { message: I18n.t("custom.projekt_content_blocks.destroy.error") }
    end
  end

  def update_position
    authorize!(:update, @content_block.projekt)

    if @content_block.insert_at(params[:position].to_i)
      render json: { status: { message: I18n.t("custom.projekt_content_blocks.update_position.success") }}
    else
      render json: { message: I18n.t("custom.projekt_content_blocks.update_position.error") }
    end
  end

  def change_with_ai
    authorize!(:update, @content_block.projekt)

    return unless check_ai_model_configured

    use_full_projekt_context = ActiveModel::Type::Boolean.new.cast(params[:use_full_projekt_context])
    allow_text_modification = ActiveModel::Type::Boolean.new.cast(params[:allow_text_modification])

    new_content_block_body =
      Ai::EditContentBlock.call(
        params[:instructions],
        params[:content_block_html],
        @content_block.projekt&.page&.title,
        @content_block.projekt&.page&.subtitle,
        projekt: @content_block.projekt,
        use_full_projekt_context: use_full_projekt_context,
        allow_text_modification: allow_text_modification
      )

    if new_content_block_body.present?
      render json: { content_block_html: new_content_block_body, status: { message: I18n.t("custom.projekt_content_blocks.change_with_ai.success") }}
    else
      render json: { status: { message: I18n.t("ai.errors.generation_failed") }}
    end
  end

  def ai_generate_with_file
    authorize!(:update, @projekt)

    unless params[:file].present?
      return render(
        json: { error: { message: I18n.t("custom.projekt_content_blocks.ai_generate_with_file.no_file") }},
        status: :unprocessable_entity
      )
    end

    Projekts::DispatchImportFromFile.call(
      projekt: @projekt,
      file: params[:file],
      user_prompt: params[:user_prompt]
    )

    status_url =
      case @namespace
      when :admin
        import_status_admin_projekt_projekt_content_blocks_path(@projekt)
      when :projekt_management
        import_status_projekt_management_projekt_projekt_content_blocks_path(@projekt)
      else
        import_status_projekt_management_projekt_projekt_content_blocks_path(@projekt)
      end

    render json: { status_url: status_url }
  end

  def ai_generate_with_prompt
    authorize!(:update, @projekt)

    unless params[:prompt].present?
      return render(
        json: { error: { message: I18n.t("custom.projekt_content_blocks.ai_generate_with_prompt.no_prompt") }},
        status: :unprocessable_entity
      )
    end

    Projekts::DispatchGenerateFromPrompt.call(
      projekt: @projekt,
      prompt: params[:prompt]
    )

    status_url =
      case @namespace
      when :admin
        import_status_admin_projekt_projekt_content_blocks_path(@projekt)
      when :projekt_management
        import_status_projekt_management_projekt_projekt_content_blocks_path(@projekt)
      else
        import_status_projekt_management_projekt_projekt_content_blocks_path(@projekt)
      end

    render json: { status_url: status_url }
  end

  def import_status
    authorize!(:update, @projekt)

    status = @projekt.import_file_status || "pending"
    response_data = @projekt.import_file_data || {}
    response_data = response_data.merge(status: status)

    if status == "completed"
      flash[:notice] = I18n.t("custom.projekt_content_blocks.import.success")
    end

    render json: response_data
  end

  def generate_with_ai
    authorize!(:update, @projekt)

    return unless check_ai_model_configured

    if params[:prompt].blank?
      return render(
        json: { error: { message: I18n.t("custom.projekt_content_blocks.ai_create.errors.no_prompt") }},
        status: :unprocessable_entity
      )
    end

    result =
      ProjektContentBlocks::Services::DispatchCreateWithAi.call(
        projekt: @projekt,
        prompt: params[:prompt],
        mode: params[:mode].presence || "add",
        category_hint: params[:category_hint],
        anchor_template_id: params[:anchor_template_id],
        use_projekt_context: params[:use_projekt_context],
        previous_content_block_id: params[:previous_content_block_id],
        add_at_top: params[:add_at_top],
        target_content_block_id: params[:target_content_block_id]
      )

    if !result.success?
      return render(
        json: { error: { message: result.error.to_s } },
        status: :unprocessable_entity
      )
    end

    render json: {
      content_block_id: result.content_block_id,
      status_url: ai_generation_status_url(result.content_block_id),
      cancel_url: cancel_ai_generation_url(result.content_block_id)
    }
  end

  def ai_generation_status
    authorize!(:update, @content_block.projekt)

    data = @content_block.ai_generation_data || {}
    status = data["status"] || "completed"

    payload = {
      status: status,
      content_block_id: @content_block.id,
      position: @content_block.position,
      mode: data["mode"]
    }

    if status == "completed"
      payload[:body_html] = @content_block.body.to_s
    end

    if status == "failed"
      payload[:error] = data["error"]
    end

    render json: payload
  end

  def cancel_ai_generation
    authorize!(:update, @content_block.projekt)

    @content_block.mark_ai_generation_status!("cancelled")

    render json: { status: { message: I18n.t("custom.projekt_content_blocks.ai_create.cancel_acknowledged") } }
  end

  def destroy_all
    authorize!(:update, @projekt)

    @projekt.content_blocks.destroy_all

    redirect_back(
      fallback_location: root_path,
      notice: I18n.t("custom.projekt_content_blocks.destroy_all.success")
    )
  end

  private

  def projekt_redirect_url
    case @namespace
    when :admin
      admin_projekt_path(@projekt, anchor: "page-content")
    when :projekt_management
      edit_projekt_management_projekt_path(@projekt, anchor: "page-content")
    else
      edit_projekt_management_projekt_path(@projekt, anchor: "page-content")
    end
  end

  def find_projekt
    if params[:projekt_id].present?
      @projekt = Projekt.find(params[:projekt_id])
    end
  end

  def find_content_block
    @content_block = ::SiteCustomization::ContentBlock.find(params[:id])
  end

  def find_ai_in_progress_content_block
    @content_block = ::SiteCustomization::ContentBlock.unscoped.find(params[:id])
  end

  def ai_generation_status_url(content_block_id)
    case @namespace
    when :admin
      ai_generation_status_admin_projekt_content_block_path(content_block_id)
    when :projekt_management
      ai_generation_status_projekt_management_projekt_content_block_path(content_block_id)
    else
      ai_generation_status_projekt_management_projekt_content_block_path(content_block_id)
    end
  end

  def cancel_ai_generation_url(content_block_id)
    case @namespace
    when :admin
      cancel_ai_generation_admin_projekt_content_block_path(content_block_id)
    when :projekt_management
      cancel_ai_generation_projekt_management_projekt_content_block_path(content_block_id)
    else
      cancel_ai_generation_projekt_management_projekt_content_block_path(content_block_id)
    end
  end

  def set_namespace
    @namespace = params[:controller].split("/").first.to_sym
  end
end
