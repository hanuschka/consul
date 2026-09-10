class ProjektSubscriptionsController < ApplicationController
  def toggle_subscription
    @projekt_subscription = ProjektSubscription.find(params[:id])
    authorize! :toggle_subscription, @projekt_subscription

    redirect_to new_user_session_path and return unless current_user

    @projekt = @projekt_subscription.projekt
    @custom_page = @projekt.page

    @projekt_subscription.update!(active: projekt_subscription_params[:active])
  end

  private

    def projekt_subscription_params
      params.require(:projekt_subscription).permit(:active)
    end
end
