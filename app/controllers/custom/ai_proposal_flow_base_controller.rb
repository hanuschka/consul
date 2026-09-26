class AiProposalFlowBaseController < ApplicationController
  include SimilarContributionsCheck

  skip_authorization_check
  before_action :authenticate_user!
  before_action :load_projekt_phase, only: [:new_flow, :generate_draft]
  before_action :load_draft_resource,
                only: [:edit_draft, :update_draft, :publish_checked, :evaluation, :publish]
  before_action :load_published_resource, only: [:success]

  def edit_draft
    assign_edit_draft_urls

    render "ai_proposal_flow/edit_draft"
  end

  # The citizen's edits are saved first so the check reads the text they are
  # actually submitting, and the flow only moves on once nothing similar was
  # found -- or once they decided to submit anyway.
  def update_draft
    @draft_resource.assign_attributes(draft_resource_params_with_image_user)

    return respond_with_invalid_draft if !@draft_resource.save

    if similar_contributions_check_requested?(@draft_resource.projekt_phase)
      return respond_with_invalid_draft if !start_similar_contributions_check(@draft_resource)

      return respond_with_started_check
    end

    advance_past_draft
  rescue StandardError => e
    Rails.logger.error("[AiProposalFlow] update_draft failed: #{e.message}")

    respond_with_draft_error
  end

  def publish_checked
    advance_past_draft
  rescue StandardError => e
    Rails.logger.error("[AiProposalFlow] publish_checked failed: #{e.message}")

    respond_with_draft_error
  end

  def publish
    publish_ai_draft

    redirect_to success_step_path
  end

  private

    def advance_past_draft
      if @draft_resource.projekt_phase.user_resource_criteria.exists?
        ProposalAiDraft::EvaluateTwoTierService.call(resource: @draft_resource)

        respond_with_next_step(evaluation_step_path)
      else
        publish_ai_draft

        respond_with_next_step(success_step_path)
      end
    end

    def publish_ai_draft
      hold_for_moderation

      UserResources::PublishService.call(@draft_resource)
    end

    # proposals.admin_accepted defaults to true, so a draft the LLM wrote is
    # accepted unless the flow says otherwise -- which would let the AI flow
    # publish straight past a phase that moderates every submission. Investments
    # have no such column and the budget flows publish them outright.
    def hold_for_moderation
      return if !@draft_resource.is_a?(::Proposal)
      return if !@draft_resource.projekt_phase.feature?("general.require_admin_acceptance")

      @draft_resource.admin_accepted = false
    end

    def respond_with_next_step(url)
      respond_to do |format|
        format.html { redirect_to url }
        format.json { render json: { status: "advanced", redirect_url: url } }
      end
    end

    def respond_with_started_check
      respond_to do |format|
        format.html { redirect_to edit_draft_step_path }

        format.json do
          render json: similar_contributions_check_started_payload(
            @draft_resource,
            publish_url: publish_checked_step_path
          )
        end
      end
    end

    def respond_with_invalid_draft
      respond_to do |format|
        format.html { render_edit_draft_form }

        format.json do
          render json: similar_contributions_invalid_payload(@draft_resource),
                 status: :unprocessable_entity
        end
      end
    end

    # The citizen's edits are already saved by the time anything downstream can
    # fail, so both paths send them back to the step with the flash rather than
    # inventing an inline error: nothing is lost on the way.
    def respond_with_draft_error
      flash[:error] = I18n.t("ai_proposal_flow.evaluate_error")

      respond_to do |format|
        format.html { redirect_to edit_draft_step_path }
        format.json { render json: { status: "failed", redirect_url: edit_draft_step_path } }
      end
    end

    def render_edit_draft_form
      assign_edit_draft_urls

      render "ai_proposal_flow/edit_draft"
    end

    def draft_resource_params_with_image_user
      params_hash = draft_resource_params.to_h

      if params_hash[:image_attributes].present?
        params_hash[:image_attributes][:user_id] = current_user.id
      end

      params_hash
    end

    def load_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    end

    def load_draft_resource
      @draft_resource = resource_class.unscoped.find(params[:id])
      verify_ownership!

      if !@draft_resource.draft?
        Rails.logger.warn("[AiProposalFlow] Draft published: #{resource_class} #{@draft_resource.id}")
        redirect_to new_flow_redirect_path
      end
    end

    def load_published_resource
      @draft_resource = resource_class.unscoped.find(params[:id])
      verify_ownership!
    end

    def verify_ownership!
      if @draft_resource.author != current_user
        raise CanCan::AccessDenied.new("Not authorized", :update, resource_class)
      end
    end

    def assign_generated_taxonomy(resource, draft_data, projekt_phase)
      assign_generated_sentiment(resource, draft_data, projekt_phase)
      assign_generated_labels(resource, draft_data, projekt_phase)
    end

    def assign_generated_sentiment(resource, draft_data, projekt_phase)
      sentiment_id = draft_data["sentiment_id"]

      return if sentiment_id.blank?
      return if !projekt_phase.sentiments.exists?(id: sentiment_id)

      resource.sentiment_id = sentiment_id
    end

    def assign_generated_labels(resource, draft_data, projekt_phase)
      generated_ids = Array(draft_data["projekt_label_ids"]).map(&:to_i)

      return if generated_ids.empty?

      valid_ids = projekt_phase.projekt_labels.where(id: generated_ids).pluck(:id)
      resource.projekt_label_ids = valid_ids if valid_ids.any?
    end

    def resource_class            = raise NotImplementedError
    def build_and_save_draft(_)   = raise NotImplementedError
    def draft_resource_params     = raise NotImplementedError
    def new_flow_redirect_path    = raise NotImplementedError
    def assign_edit_draft_urls    = raise NotImplementedError
    def edit_draft_step_path      = raise NotImplementedError
    def publish_checked_step_path = raise NotImplementedError
    def evaluation_step_path      = raise NotImplementedError
    def success_step_path         = raise NotImplementedError
end
