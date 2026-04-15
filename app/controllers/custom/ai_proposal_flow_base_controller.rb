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

    def resource_class            = raise NotImplementedError
    def build_and_save_draft(_)   = raise NotImplementedError
    def draft_resource_params     = raise NotImplementedError
    def new_flow_redirect_path    = raise NotImplementedError
end
