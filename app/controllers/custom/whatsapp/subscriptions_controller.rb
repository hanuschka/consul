class Whatsapp::SubscriptionsController < ApplicationController
  before_action :ensure_feature_enabled!
  before_action :authenticate_user!
  before_action :find_account

  skip_authorization_check

  def create
    @account.update!(opt_in_at: Time.current, opt_out_at: nil)

    redirect_to account_path, notice: t("whatsapp.subscription.opted_in")
  end

  def destroy
    @account.update!(opt_out_at: Time.current)

    redirect_to account_path, notice: t("whatsapp.subscription.opted_out")
  end

  private

    def ensure_feature_enabled!
      return if ::Whatsapp.enabled?

      redirect_to root_path
    end

    def find_account
      @account = current_user.whatsapp_account

      return if @account.present?

      redirect_to account_path, alert: t("whatsapp.subscription.not_linked")
    end
end
