class BudgetInvestments::GenerateController < AiProposalFlowBaseController
  def new_flow
    @generate_draft_url = generate_budget_investment_draft_path
    render "ai_proposal_flow/new_flow"
  end

  def generate_draft
    draft_data = ProposalAiDraft::GenerateDraftService.call(
      idea_text: params[:idea_text],
      projekt_phase: @projekt_phase
    )
    investment = build_and_save_draft(draft_data)
    redirect_to generate_budget_investment_edit_draft_path(investment)
  rescue StandardError => e
    raise e if Rails.env.development?

    Rails.logger.error("[AiProposalFlow] generate_draft failed: #{e.message}")

    flash[:error] = I18n.t("ai_proposal_flow.generate_error")

    redirect_to generate_budget_investment_new_path(projekt_phase_id: @projekt_phase.id, idea_text: params[:idea_text])
  end

  def edit_draft
    @generate_image_url = ai_generate_image_path
    @update_draft_url   = generate_budget_investment_update_draft_path(@draft_resource)
    @back_to_new_url    = generate_budget_investment_new_path(
      projekt_phase_id: @draft_resource.projekt_phase.id,
      idea_text: @draft_resource.ai_idea_text
    )

    render "ai_proposal_flow/edit_draft"
  end

  def update_draft
    params_with_image_user = draft_resource_params_with_image_user
    @draft_resource.update!(params_with_image_user)

    if @draft_resource.projekt_phase.user_resource_criteria.exists?
      evaluation = ProposalAiDraft::EvaluateCriteriaService.call(resource: @draft_resource)
      @draft_resource.update!(ai_evaluation_result: evaluation)

      redirect_to generate_budget_investment_evaluation_path(@draft_resource)
    else
      @draft_resource.update!(draft: false, published_at: Time.current)

      redirect_to generate_budget_investment_success_path(@draft_resource)
    end

  rescue StandardError => e
    Rails.logger.error("[AiProposalFlow] update_draft failed: #{e.message}")

    flash[:error] = I18n.t("ai_proposal_flow.evaluate_error")

    @generate_image_url = ai_generate_image_path
    @update_draft_url   = generate_budget_investment_update_draft_path(@draft_resource)
    @back_to_new_url    = generate_budget_investment_new_path(
      projekt_phase_id: @draft_resource.projekt_phase.id,
      idea_text: @draft_resource.ai_idea_text
    )

    render "ai_proposal_flow/edit_draft"
  end

  def evaluation
    @back_to_edit_url = generate_budget_investment_edit_draft_path(@draft_resource)
    @publish_url      = generate_budget_investment_publish_path(@draft_resource)
    render "ai_proposal_flow/evaluation"
  end

  def publish
    @draft_resource.update!(draft: false, published_at: Time.current)
    redirect_to generate_budget_investment_success_path(@draft_resource)
  end

  def success
    @new_idea_url = generate_budget_investment_new_path(projekt_phase_id: @draft_resource.projekt_phase.id)
    @resource_url = budget_investment_path(@draft_resource.budget, @draft_resource)
    render "ai_proposal_flow/success"
  end

  private

    def resource_class = Budget::Investment

    def new_flow_redirect_path
      generate_budget_investment_new_path(projekt_phase_id: @draft_resource.projekt_phase.id)
    end

    def build_and_save_draft(draft_data)
      investment = Budget::Investment.new(
        draft: true,
        budget: @projekt_phase.budget,
        heading: @projekt_phase.budget.heading,
        author: current_user,
        ai_idea_text: params[:idea_text],
        ai_image_prompt: draft_data["image_prompt"]
      )
      investment.translations.build(
        locale: I18n.locale,
        title: draft_data["title"],
        description: draft_data["description"]
      )
      investment.tag_list = draft_data["tag_list"]
      investment.save!(validate: false)
      investment
    end

    def draft_resource_params_with_image_user
      params_hash = draft_resource_params.to_h

      if params_hash[:image_attributes].present?
        params_hash[:image_attributes][:user_id] = current_user.id
      end

      params_hash
    end

    def draft_resource_params
      params.require(:budget_investment).permit(
        :title, :description, :tag_list, :video_url, :on_behalf_of,
        image_attributes: [:attachment, :title, :credits, :cached_attachment, :_destroy, :user_id]
      )
    end

end
