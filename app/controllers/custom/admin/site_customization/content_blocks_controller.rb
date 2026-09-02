require_dependency Rails.root.join(
  "app", "controllers", "admin", "site_customization", "content_blocks_controller"
).to_s

class Admin::SiteCustomization::ContentBlocksController
  include AiErrorHandling
  include SiteContentBlocksAiActions

  skip_load_and_authorize_resource only: [
    :update_inline, :change_with_ai,
    :generate_with_ai, :ai_generation_status, :cancel_ai_generation
  ]

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
end
