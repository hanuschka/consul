class SubscriptionsController < ApplicationController
  before_action :set_user
  around_action :set_user_locale
  skip_authorization_check

  def edit
  end

  def update
    @user.update!(subscriptions_params)
    redirect_to edit_subscriptions_path(token: @user.subscriptions_token),
                notice: t("flash.actions.save_changes.notice")
  end

  def update_projekt
    @projekt = Projekt.find(params[:projekt_id])

    if ActiveModel::Type::Boolean.new.cast(params.dig(:projekt_subscription, :active))
      ProjektSubscription.follow!(user: @user, projekt: @projekt)
    else
      ProjektSubscription.unfollow!(user: @user, projekt: @projekt)
    end

    @projekt_subscription = ProjektSubscription.find_by!(user: @user, projekt: @projekt)
  end

  def cancel_projekts
    ProjektSubscription.where(user_id: @user.id).update_all(active: false, updated_at: Time.current)

    redirect_to edit_subscriptions_path(token: @user.subscriptions_token),
                notice: t("flash.actions.save_changes.notice")
  end

  private

    def set_user
      @user = if params[:token].present?
                User.find_by!(subscriptions_token: params[:token])
              else
                current_user || raise(CanCan::AccessDenied)
              end
    end

    def subscriptions_params
      params.require(:user).permit(allowed_params)
    end

    def allowed_params
      [:email_on_comment, :email_on_comment_reply, :email_on_direct_message, :email_digest, :newsletter]
    end

    def set_user_locale(&action)
      if params[:locale].blank?
        session[:locale] = I18n.available_locales.find { |locale| locale == @user.locale&.to_sym }
      end
      I18n.with_locale(session[:locale], &action)
    end
end
