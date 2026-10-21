class BudgetInvestments::GenerateController < AiProposalFlowBaseController
  def new_flow
    @generate_draft_url = generate_budget_investment_draft_path(projekt_phase_id: @projekt_phase.id)
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

  def evaluation
    @back_to_edit_url = generate_budget_investment_edit_draft_path(@draft_resource)
    @publish_url      = generate_budget_investment_publish_path(@draft_resource)
    render "ai_proposal_flow/evaluation"
  end

  def success
    @new_idea_url = generate_budget_investment_new_path(projekt_phase_id: @draft_resource.projekt_phase.id)
    @resource_url = budget_investment_path(@draft_resource.budget, @draft_resource)
    render "ai_proposal_flow/success"
  end

  private

    def resource_class = Budget::Investment

    def assign_edit_draft_urls
      @generate_image_url = ai_generate_image_and_assign_to_resource_path
      @update_draft_url   = generate_budget_investment_update_draft_path(@draft_resource)
      @back_to_new_url    = generate_budget_investment_new_path(
        projekt_phase_id: @draft_resource.projekt_phase.id,
        idea_text: @draft_resource.ai_idea_text
      )
    end

    def edit_draft_step_path      = generate_budget_investment_edit_draft_path(@draft_resource)
    def publish_checked_step_path = generate_budget_investment_publish_checked_path(@draft_resource)
    def evaluation_step_path      = generate_budget_investment_evaluation_path(@draft_resource)
    def success_step_path         = generate_budget_investment_success_path(@draft_resource)

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
      assign_generated_taxonomy(investment, draft_data, @projekt_phase)
      investment.save!(validate: false)
      investment
    end

    def draft_resource_params
      params.require(:budget_investment).permit(
        :title, :description, :tag_list, :video_url, :on_behalf_of,
        :sentiment_id,
        projekt_label_ids: [],
        image_attributes: [:attachment, :title, :credits, :cached_attachment, :_destroy, :user_id]
      )
    end

end
