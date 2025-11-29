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

  def refresh_stats
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    @projekt_phase.stats_version&.destroy!

    redirect_to page_path(@projekt_phase.projekt.page.slug,
                          projekt_phase_id: @projekt_phase.id,
                          section: "stats")
  end

  def refresh_ai_stats
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    @projekt_phase.generate_ai_stats

    redirect_to page_path(@projekt_phase.projekt.page.slug,
                          projekt_phase_id: @projekt_phase.id,
                          section: "stats")
  end
end
