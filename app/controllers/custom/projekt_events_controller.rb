class ProjektEventsController < ApplicationController
  include CustomHelper
  include ProposalsHelper
  include ProjektControllerHelper

  skip_authorization_check
  has_filters %w[incoming past], only: [:index]

  def index
    @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : @valid_filters.first
    order = @current_filter == "incoming" ? :asc : :desc

    @projekt_events =
      ProjektEvent
        .with_active_projekt
        .send("sort_by_#{@current_filter}")
        .reorder(datetime: order)
        .page(params[:page]).per(10)

    if Setting.new_design_enabled?
      render :index_new
    else
      render :index
    end
  end
end
