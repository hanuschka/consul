class MunicipalPlansController < ApplicationController
  include FeatureFlags

  skip_authorization_check

  feature_flag :municipal_plans

  def index
    @municipal_plans = MunicipalPlan.published.sorted
  end

  def show
    @municipal_plan = MunicipalPlan.published.find(params[:id])
  end
end
