class Adm::Newsletters::ContentBlocksController < Adm::BaseController
  include AiErrorHandling

  before_action :find_newsletter
  before_action :find_content_block, only: [:update, :destroy, :update_position, :change_with_ai]
  before_action :find_ai_in_progress_content_block, only: [:ai_generation_status, :cancel_ai_generation]

  def create
    @content_block = @newsletter.content_blocks.build(
      name: "custom",
      body: params[:html],
      key: generated_key,
      locale: "de"
    )
    authorize_content_block

    if @content_block.save
      apply_insert_position

      render json: {
        content_block: { id: @content_block.id, urls: content_block_urls(@content_block) },
        status: { message: t(".success") }
      }
    else
      render json: { error: { message: t(".error") } }, status: :unprocessable_entity
    end
  end

  def update
    authorize_content_block

    update_params = {}
    update_params[:body] = params[:html] if params.key?(:html)
    update_params[:margin_bottom] = params[:margin_bottom] if params.key?(:margin_bottom)

    if @content_block.update(update_params)
      render json: {
        body: @content_block.body,
        stripped: @content_block.body_stripped?,
        status: { message: t(".success") }
      }
    else
      render json: { error: { message: t(".error") } }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_content_block

    if @content_block.destroy
      render json: { status: { message: t(".success") } }
    else
      render json: { error: { message: t(".error") } }, status: :unprocessable_entity
    end
  end

  def update_position
    authorize_content_block

    if @content_block.insert_at(params[:position].to_i)
      render json: { status: { message: t(".success") } }
    else
      render json: { error: { message: t(".error") } }, status: :unprocessable_entity
    end
  end

  def change_with_ai
    authorize_content_block

    return unless check_ai_model_configured

    allow_text_modification = ActiveModel::Type::Boolean.new.cast(params[:allow_text_modification])

    new_content_block_body =
      Ai::EditContentBlock.call(
        params[:instructions],
        params[:content_block_html],
        @newsletter.subject,
        nil,
        projekt: nil,
        use_full_projekt_context: false,
        allow_text_modification: allow_text_modification
      )

    if new_content_block_body.present?
      render json: {
        content_block_html: new_content_block_body,
        status: { message: t(".success") }
      }
    else
      render json: { status: { message: I18n.t("ai.errors.generation_failed") } }
    end
  end

  def generate_with_ai
    @content_block = @newsletter.content_blocks.build
    authorize_content_block

    return unless check_ai_model_configured

    if params[:prompt].blank?
      return render(json: { error: { message: t(".no_prompt") } }, status: :unprocessable_entity)
    end

    result =
      NewsletterContentBlocks::DispatchCreateWithAi.call(
        newsletter: @newsletter,
        prompt: params[:prompt],
        mode: params[:mode].presence || "add",
        category_hint: params[:category_hint],
        anchor_template_id: params[:anchor_template_id],
        previous_content_block_id: params[:previous_content_block_id],
        add_at_top: params[:add_at_top],
        target_content_block_id: params[:target_content_block_id]
      )

    if !result.success?
      return render(json: { error: { message: result.error.to_s } }, status: :unprocessable_entity)
    end

    render json: {
      content_block_id: result.content_block_id,
      status_url: ai_generation_status_adm_newsletter_content_block_path(@newsletter, result.content_block_id),
      cancel_url: cancel_ai_generation_adm_newsletter_content_block_path(@newsletter, result.content_block_id)
    }
  end

  def ai_generation_status
    authorize_content_block

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
      payload[:urls] = content_block_urls(@content_block)
    end

    if status == "failed"
      payload[:error] = data["error"]
    end

    render json: payload
  end

  def cancel_ai_generation
    authorize_content_block

    @content_block.mark_ai_generation_status!("cancelled")

    render json: { status: { message: t(".success") } }
  end

  private

    def find_newsletter
      @newsletter = Newsletter.find(params[:newsletter_id])
    end

    def find_content_block
      @content_block = @newsletter.content_blocks.find(params[:id])
    end

    def find_ai_in_progress_content_block
      @content_block =
        ::SiteCustomization::ContentBlock
          .unscoped
          .where(newsletter_id: @newsletter.id)
          .find(params[:id])
    end

    def authorize_content_block
      authorize @content_block, policy_class: Adm::Newsletters::ContentBlockPolicy
    end

    def content_block_urls(content_block)
      {
        update_url: adm_newsletter_content_block_path(@newsletter, content_block),
        destroy_url: adm_newsletter_content_block_path(@newsletter, content_block),
        update_position_url: update_position_adm_newsletter_content_block_path(@newsletter, content_block),
        ai_url: change_with_ai_adm_newsletter_content_block_path(@newsletter, content_block)
      }
    end

    def generated_key
      "newsletter_content_block_#{@newsletter.id}_#{@newsletter.content_blocks.count + 1}_#{DateTime.now.to_i}"
    end

    def apply_insert_position
      if params[:previous_content_block_id].present?
        previous_content_block = @newsletter.content_blocks.find(params[:previous_content_block_id])
        @content_block.insert_at(previous_content_block.position + 1)
      else
        @content_block.move_to_top
      end
    end
end
