class MunicipalPlansController < ApplicationController
  include FeatureFlags

  skip_authorization_check

  feature_flag :municipal_plans

  def index
    @municipal_plans = MunicipalPlan.published
                                    .includes(:topics, :districts)
                                    .sorted
                                    .page(params[:page])
  end

  def show
    @municipal_plan = MunicipalPlan.published.find(params[:id])
  end
end
