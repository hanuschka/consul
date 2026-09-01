class ProjektManagement::SiteCustomization::ContentBlocksController < ProjektManagement::BaseController
  include AiErrorHandling
  include SiteContentBlocksAiActions

  load_and_authorize_resource :content_block, class: "SiteCustomization::ContentBlock",
                               except: [
                                 :delete_heading_content_block,
                                 :edit_heading_content_block,
                                 :update_heading_content_block,
                                 :update_inline,
                                 :change_with_ai,
                                 :generate_with_ai,
                                 :ai_generation_status,
                                 :cancel_ai_generation
                               ]

  def edit
    @selected_content_block = @content_block.name
    render "custom/admin/site_customization/content_blocks/edit"
  end

  def update
    if @content_block.update(content_block_params)
      notice = t("admin.site_customization.content_blocks.update.notice")
      return_to = params[:return_to]
      redirect_to (return_to.presence || admin_site_customization_content_blocks_path), notice: notice
    else
      flash.now[:error] = t("admin.site_customization.content_blocks.update.error")
      render :edit
    end
  end

  def update_inline
    @content_block = SiteCustomization::ContentBlock.find(params[:id])
    authorize!(:update, @content_block)

    update_params = {}
    update_params[:body] = params[:html] if params.key?(:html)
    update_params[:margin_bottom] = params[:margin_bottom] if params.key?(:margin_bottom)

    if @content_block.update(update_params)
      render json: {
        body: @content_block.body,
        stripped: @content_block.body_stripped?,
        status: { message: I18n.t("admin.site_customization.content_blocks.update.notice") }
      }
    else
      render json: { message: I18n.t("admin.site_customization.content_blocks.update.error") }, status: :unprocessable_entity
    end
  end

  def change_with_ai
    @content_block = SiteCustomization::ContentBlock.find(params[:id])
    authorize!(:update, @content_block)

    return if check_ai_model_configured == false

    allow_text_modification = ActiveModel::Type::Boolean.new.cast(params[:allow_text_modification])

    new_content_block_body =
      Ai::EditContentBlock.call(
        params[:instructions],
        params[:content_block_html],
        nil,
        nil,
        projekt: nil,
        use_full_projekt_context: false,
        allow_text_modification: allow_text_modification
      )

    if new_content_block_body.present?
      render json: {
        content_block_html: new_content_block_body,
        status: { message: I18n.t("admin.site_customization.content_blocks.update.notice") }
      }
    else
      render json: { status: { message: I18n.t("ai.errors.generation_failed") } }
    end
  end

  private

    def content_block_params
      params.require(:site_customization_content_block).permit(allowed_params)
    end

    def allowed_params
      [:name, :locale, :body, :margin_bottom]
    end
end
