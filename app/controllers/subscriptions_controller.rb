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

  def cancel_projekts
    @user.projekt_subscriptions.update_all(active: false)

    redirect_to edit_subscriptions_path(token: @user.subscriptions_token),
                notice: t("flash.actions.save_changes.notice")
  end

  def toggle_projekt
    @projekt_subscription = ProjektSubscription.find_by!(id: params[:projekt_subscription_id], user: @user)
    @projekt_subscription.update!(active: projekt_subscription_params[:active])
  end

  # Reached from a link in a newsletter sent to one projekt's subscribers, so it
  # answers to GET and identifies the citizen by their subscriptions token.
  def unsubscribe_projekt
    projekt = Projekt.find(params[:projekt_id])
    @user.projekt_subscriptions.where(projekt_id: projekt.id).update_all(active: false, updated_at: Time.current)

    redirect_to edit_subscriptions_path(token: @user.subscriptions_token),
                notice: t("custom.account.subscriptions.projekts.unsubscribed_notice", projekt: projekt.name)
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

    def projekt_subscription_params
      params.require(:projekt_subscription).permit(:active)
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
