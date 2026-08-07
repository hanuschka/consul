class Whatsapp::SubscriptionsController < ApplicationController
  include WhatsappFeatureGated

  before_action :authenticate_user!
  before_action :find_account

  skip_authorization_check

  def create
    @account.opt_in!

    redirect_to account_path, notice: t("whatsapp.subscription.opted_in")
  end

  def destroy
    @account.opt_out!

    redirect_to account_path, notice: t("whatsapp.subscription.opted_out")
  end

  private

    def find_account
      @account = current_user.whatsapp_account

      return if @account.present?

      redirect_to account_path, alert: t("whatsapp.subscription.not_linked")
    end
end
