class Proposals::GenerateController < AiProposalFlowBaseController
  def new_flow
    @generate_draft_url = generate_proposal_draft_path(projekt_phase_id: @projekt_phase.id)
    render "ai_proposal_flow/new_flow"
  end

  def generate_draft
    draft_data = ProposalAiDraft::GenerateDraftService.call(
      idea_text: params[:idea_text],
      projekt_phase: @projekt_phase
    )
    proposal = build_and_save_draft(draft_data)
    redirect_to generate_proposal_edit_draft_path(proposal)
  rescue StandardError => e
    raise e if Rails.env.development?

    flash[:error] = I18n.t("ai_proposal_flow.generate_error")
    redirect_to generate_proposal_new_path(projekt_phase_id: @projekt_phase.id, idea_text: params[:idea_text])
  end

  def edit_draft
    @generate_image_url = ai_generate_image_and_assign_to_resource_path
    @update_draft_url   = generate_proposal_update_draft_path(@draft_resource)
    @back_to_new_url    = generate_proposal_new_path(projekt_phase_id: @draft_resource.projekt_phase_id,
idea_text: @draft_resource.ai_idea_text)

    render "ai_proposal_flow/edit_draft"
  end

  def update_draft
    params_with_image_user = draft_resource_params_with_image_user
    @draft_resource.update!(params_with_image_user)

    if @draft_resource.projekt_phase.user_resource_criteria.exists?
      ProposalAiDraft::EvaluateTwoTierService.call(resource: @draft_resource)

      redirect_to generate_proposal_evaluation_path(@draft_resource)
    else
      @draft_resource.update!(draft: false, published_at: Time.current)

      redirect_to generate_proposal_success_path(@draft_resource)
    end

  rescue StandardError => e
    Rails.logger.error("[AiProposalFlow] update_draft failed: #{e.message}")

    flash[:error] = I18n.t("ai_proposal_flow.evaluate_error")

    @generate_image_url = ai_generate_image_and_assign_to_resource_path
    @update_draft_url   = generate_proposal_update_draft_path(@draft_resource)
    @back_to_new_url    = generate_proposal_new_path(projekt_phase_id: @draft_resource.projekt_phase_id,
idea_text: @draft_resource.ai_idea_text)

    render "ai_proposal_flow/edit_draft"
  end

  def evaluation
    @back_to_edit_url = generate_proposal_edit_draft_path(@draft_resource)
    @publish_url      = generate_proposal_publish_path(@draft_resource)

    render "ai_proposal_flow/evaluation"
  end

  def publish
    @draft_resource.update!(draft: false, published_at: Time.current)

    redirect_to generate_proposal_success_path(@draft_resource)
  end

  def success
    @new_idea_url = generate_proposal_new_path(projekt_phase_id: @draft_resource.projekt_phase_id)
    @resource_url = proposal_path(@draft_resource)

    render "ai_proposal_flow/success"
  end

  private

    def draft_resource_params_with_image_user
      params_hash = draft_resource_params.to_h
      if params_hash[:image_attributes].present?
        params_hash[:image_attributes][:user_id] = current_user.id
      end
      params_hash
    end

    def resource_class = Proposal

    def new_flow_redirect_path
      generate_proposal_new_path(projekt_phase_id: @draft_resource.projekt_phase_id)
    end

    def build_and_save_draft(draft_data)
      proposal = Proposal.new(
        draft: true,
        projekt_phase: @projekt_phase,
        author: current_user,
        ai_idea_text: params[:idea_text],
        ai_image_prompt: draft_data["image_prompt"]
      )
      proposal.translations.build(
        locale: I18n.locale,
        title: draft_data["title"],
        description: draft_data["description"]
      )
      proposal.tag_list = draft_data["tag_list"]
      assign_generated_taxonomy(proposal, draft_data, @projekt_phase)
      proposal.save!(validate: false)

      if draft_data["location"].present?
        ProposalAiDraft::GeocodeLocationService.call(
          mappable: proposal,
          location_name: draft_data["location"]
        )
      end

      proposal
    end

    def draft_resource_params
      params.require(:proposal).permit(
        :title, :description, :tag_list, :video_url, :on_behalf_of, :responsible_name,
        :sentiment_id,
        projekt_label_ids: [],
        image_attributes: [:attachment, :title, :credits, :cached_attachment, :_destroy, :user_id]
      )
    end
end
