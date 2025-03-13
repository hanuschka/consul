class BudgetsController < ApplicationController
  include GuestUsers
  include FeatureFlags
  include BudgetsHelper
  feature_flag :budgets

  before_action :load_budget, only: :show
  before_action :load_current_budget, only: :index
  load_and_authorize_resource

  respond_to :html, :js

  def show
    raise ActionController::RoutingError, "Not Found" # unless budget_published?(@budget)
  end

  def index
    raise ActionController::RoutingError, "Not Found"
    # @finished_budgets = @budgets.finished.order(created_at: :desc)
  end

  def read_stats
    raise ActionController::RoutingError, "Not Found" unless params[:section] == "stats"

    authorize! :read_stats, @budget

    if params["stats_section"].in? %w[accepting reviewing selecting valuating publishing_prices balloting]
      @stats = Budget::PhaseStats.new(@budget, params["stats_section"])
    else
      @stats = Budget::Stats.new(@budget)
    end

    respond_to do |format|
      format.csv do
        send_data CsvServices::BudgetStatsExporter.call(@stats),
                  filename: "budget-#{@budget.id}-stats-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
      end
    end
  end

  private

    def load_budget
      @budget = Budget.find_by_slug_or_id! params[:id]
    end

    def load_current_budget
      @budget = current_budget
    end
end
