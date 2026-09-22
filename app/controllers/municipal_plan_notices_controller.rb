class MunicipalPlanNoticesController < ApplicationController
  include FeatureFlags

  skip_authorization_check

  feature_flag :municipal_plans

  invisible_captcha only: [:create], honeypot: :subtitle, scope: :municipal_plan_notice,
                    timestamp_enabled: false

  def create
    @municipal_plan = MunicipalPlan.published.find(params[:municipal_plan_id])
    @notice = @municipal_plan.notices.new(notice_params)

    if @notice.save
      ::MunicipalPlans::NoticeNotificationService.call(@notice)
      redirect_to municipal_plan_path(@municipal_plan), notice: t(".success")
    else
      render "municipal_plans/show", status: :unprocessable_entity
    end
  end

  private

    def notice_params
      params.require(:municipal_plan_notice).permit(:name, :email, :body)
    end
end
