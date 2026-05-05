class ProjektEventsController < ApplicationController
  include CustomHelper
  include ProposalsHelper
  include ProjektControllerHelper
  include LandingPageResolvable

  before_action :check_projekt_events_page_enabled, only: :index

  skip_authorization_check
  has_filters %w[incoming all past], only: [:index]

  def index
    resolve_landing_page_from_slug
    @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : @valid_filters.first
    order = @current_filter == "incoming" ? :asc : :desc

    @projekt_events =
      ProjektEvent
        .with_active_projekt
        .send("sort_by_#{@current_filter}")
        .reorder(datetime: order)

    if @landing_page.present?
      @projekt_events =
        @projekt_events
          .joins(projekt_phase: :projekt)
          .where(projekts: { id: landing_page_scoped_projekt_ids })
    end

    @projekt_events = @projekt_events.page(params[:page]).per(10)

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end
    end
  end

  private

    def check_projekt_events_page_enabled
      raise FeatureFlags::FeatureDisabled, :projekt_events_page unless Setting["extended_feature.general.enable_projekt_events_page"].present?
    end
end
