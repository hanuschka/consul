class AiProposalFlowBaseController < ApplicationController
  skip_authorization_check
  before_action :authenticate_user!
  before_action :load_projekt_phase, only: [:new_flow, :generate_draft]
  before_action :load_draft_resource, only: [:edit_draft, :update_draft, :evaluation, :publish]
  before_action :load_published_resource, only: [:success]

  private

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
end
