class MunicipalPlansController < ApplicationController
  include FeatureFlags
  include Search

  skip_authorization_check

  feature_flag :municipal_plans

  before_action :parse_search_terms, only: :archive
  before_action :set_search_order, only: :archive

  has_orders %w[relevance given_order content_updated_at title], only: [:index, :archive]

  def index
    load_overview(MunicipalPlan.published)
  end

  # The archive shows the same presentation with the same filters, over the other half of the list.
  def archive
    load_overview(MunicipalPlan.archived)
    render :index
  end

  # An archived Vorhaben keeps its address, so existing links and search results keep working.
  def show
    @municipal_plan = MunicipalPlan.publicly_visible.find(params[:id])
  end

  private

    def load_overview(scope)
      @districts = RegisteredAddress::District.all.sort_by(&:name_for_display)
      @topics = MunicipalPlan::Topic.all

      @municipal_plans = MunicipalPlansQuery.new(
        scope.includes(:topics, :districts), filter_params
      ).call
      @municipal_plans = @municipal_plans.pg_search(@search_terms) if @search_terms.present?
      @municipal_plans = apply_order(@municipal_plans).page(params[:page])
    end

    def filter_params
      params.permit(:updated_from, :updated_to, districts: [], topics: [],
                                                participation: [], recency: []).to_h.symbolize_keys
    end

    # "relevance" is what pg_search already ordered by, so it deliberately applies nothing further.
    def apply_order(scope)
      case @current_order
      when "content_updated_at" then scope.sort_by_content_updated_at
      when "title" then scope.sort_by_title
      when "relevance" then scope
      else scope.sorted
      end
    end
end
