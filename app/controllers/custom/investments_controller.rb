class InvestmentsController < ApplicationController
  include Search
  include RandomSeed

  before_action :set_random_seed, only: :index

  skip_authorization_check only: [:index]

  has_orders %w[random supports ballots ballot_line_weight newest], only: :index

  def index
    @investments = Budget::Investment.all
    @budgets = Budget.where(id: @investments.map(&:budget_id).uniq)

    set_status_filter_options

    filter_by_budget
    filter_by_status
    filter_by_searched

    @investment_coordinates = MapLocation.where(investment_id: @investments).map(&:json_data)
    @investments = @investments.perform_sort_by(@current_order, session[:random_seed]).page(params[:page]).per(12)
  end

  private

    def filter_by_budget
      return unless params[:budget_id].present?
      return unless @budgets.map(&:id).include?(params[:budget_id].to_i)

      @investments = @investments.where(budget_id: params[:budget_id])
    end

    def filter_by_status
      @investments = @investments.selected if params[:status] == "selected"
      @investments = @investments.unfeasible if params[:status] == "unfeasible"
    end

    def filter_by_searched
      @investments = @investments.search(@search_terms) if @search_terms.present?
    end

    def set_status_filter_options
      @status_filter_options = []

      @status_filter_options << [t("budgets.investments.index.filters.selected"), "selected"] if @investments.selected.any?
      @status_filter_options << [t("budgets.investments.index.filters.unfeasible"), "unfeasible"] if @investments.unfeasible.any?
    end
end
