module SiteContentBlocksAiActions
  extend ActiveSupport::Concern
  include AiErrorHandling

  def generate_with_ai
    content_block = ::SiteCustomization::ContentBlock.find(params[:id])
    authorize!(:update, content_block)

    return if check_ai_model_configured == false

    if params[:prompt].blank?
      return render(
        json: { error: { message: I18n.t("custom.projekt_content_blocks.ai_create.errors.no_prompt") }},
        status: :unprocessable_entity
      )
    end

    result =
      ProjektContentBlocks::Services::DispatchCreateWithAi.call(
        projekt: nil,
        prompt: params[:prompt],
        mode: "replace",
        category_hint: params[:category_hint],
        target_content_block_id: content_block.id
      )

    if !result.success?
      return render(json: { error: { message: result.error.to_s }}, status: :unprocessable_entity)
    end

    render json: {
      content_block_id: result.content_block_id,
      status_url: ai_generation_status_url_for(result.content_block_id),
      cancel_url: cancel_ai_generation_url_for(result.content_block_id)
    }
  end

  def ai_generation_status
    content_block = find_ai_in_progress_content_block
    authorize!(:update, content_block)

    data = content_block.ai_generation_data || {}
    status = data["status"] || "completed"

    payload = {
      status: status,
      content_block_id: content_block.id,
      mode: data["mode"]
    }

    if status == "completed"
      payload[:body_html] = content_block.body.to_s
    end

    if status == "failed"
      payload[:error] = data["error"]
    end

    render json: payload
  end

  def cancel_ai_generation
    content_block = find_ai_in_progress_content_block
    authorize!(:update, content_block)

    content_block.mark_ai_generation_status!("cancelled")

    render json: {
      status: { message: I18n.t("custom.projekt_content_blocks.ai_create.cancel_acknowledged") }
    }
  end

  private

    def find_ai_in_progress_content_block
      ::SiteCustomization::ContentBlock.unscoped.find(params[:id])
    end

    def admin_namespace?
      params[:controller].to_s.start_with?("admin/")
    end

    def ai_generation_status_url_for(content_block_id)
      if admin_namespace?
        ai_generation_status_admin_site_customization_content_block_path(content_block_id)
      else
        ai_generation_status_projekt_management_site_customization_content_block_path(content_block_id)
      end
    end

    def cancel_ai_generation_url_for(content_block_id)
      if admin_namespace?
        cancel_ai_generation_admin_site_customization_content_block_path(content_block_id)
      else
        cancel_ai_generation_projekt_management_site_customization_content_block_path(content_block_id)
      end
    end
end
