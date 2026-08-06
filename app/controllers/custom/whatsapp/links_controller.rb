class Whatsapp::LinksController < ApplicationController
  before_action :ensure_feature_enabled!
  before_action :authenticate_user!
  before_action :find_pending_account

  skip_authorization_check

  def show
    @token = params[:token]
  end

  def create
    account =
      ::Whatsapp::ConfirmLinkService.call(
        token: params[:token],
        user: current_user,
        broadcast_consent: broadcast_consent?
      )

    if account.blank?
      return redirect_to account_path, alert: t("whatsapp.link.failure")
    end

    ::Whatsapp::Outbound.text(
      account: account,
      body: t("whatsapp.bot.link_confirmed", name: account.user.name)
    )

    ::Whatsapp::NextStepService.call(conversation: account.conversation)

    redirect_to account_path, notice: t("whatsapp.link.success")
  end

  private

    def ensure_feature_enabled!
      return if ::Whatsapp.enabled?

      redirect_to root_path
    end

    def find_pending_account
      @account = WhatsappAccount.find_by(link_token: params[:token].to_s)

      return if @account.present? && @account.link_token_valid?

      redirect_to account_path, alert: t("whatsapp.link.failure")
    end

    def broadcast_consent?
      ActiveModel::Type::Boolean.new.cast(params[:broadcast_consent]).present?
    end
end
