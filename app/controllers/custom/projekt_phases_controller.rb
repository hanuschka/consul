class ProjektPhasesController < ApplicationController
  # include CustomHelper
  # include ProposalsHelper
  # include ProjektControllerHelper

  skip_authorization_check only: [:map_html]

  def toggle_subscription
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize! :toggle_subscription, @projekt_phase

    redirect_to new_user_session_path and return unless current_user

    if @projekt_phase.subscribed?(current_user)
      @projekt_phase.unsubscribe(current_user)
    else
      @projekt_phase.subscribe(current_user)
    end
  end

  def map_html
    @projekt_phase = ProjektPhase.find(params[:id])
    @projekt = @projekt_phase.projekt
  end
end
