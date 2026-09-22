require_dependency Rails.root.join(
  "app", "controllers", "admin", "site_customization", "content_blocks_controller"
).to_s

class Admin::SiteCustomization::ContentBlocksController
  include AiErrorHandling
  include SiteContentBlocksAiActions

  # The core controller names this resource, so a nameless skip would never
  # match it and CanCan would keep loading the content block underneath.
  skip_load_and_authorize_resource :content_block, only: [
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
end
