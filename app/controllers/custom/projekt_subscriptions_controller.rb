class ProjektSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def update
    @projekt = Projekt.find(params[:projekt_id])
    authorize! :update, ProjektSubscription.new(projekt: @projekt, user: current_user)

    if ActiveModel::Type::Boolean.new.cast(projekt_subscription_params[:active])
      ProjektSubscription.follow_visible!(user: current_user, projekt: @projekt)
    else
      ProjektSubscription.unfollow!(user: current_user, projekt: @projekt)
    end

    @projekt_subscription = ProjektSubscription.find_by!(projekt: @projekt, user: current_user)
  end

  private

    def projekt_subscription_params
      params.permit(projekt_subscription: [:active]).require(:projekt_subscription)
    end
end
