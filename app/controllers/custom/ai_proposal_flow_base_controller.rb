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
      authorize! :update, @draft_resource

      unless @draft_resource.draft?
        Rails.logger.warn("[AiProposalFlow] Draft published: proposal #{@draft_resource.id}")
        flash[:notice] = "Ihr Vorschlag wurde erfolgreich eingereicht!"
        redirect_to @draft_resource
      end
    end

    def load_published_resource
      @draft_resource = resource_class.unscoped.find(params[:id])
      authorize! :update, @draft_resource
    end

    def resource_class          = raise NotImplementedError
    def build_and_save_draft(_) = raise NotImplementedError
    def draft_resource_params   = raise NotImplementedError
end
