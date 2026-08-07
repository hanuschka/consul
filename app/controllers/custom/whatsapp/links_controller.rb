class Whatsapp::LinksController < ApplicationController
  include WhatsappFeatureGated

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

    ::Whatsapp::ConfirmLinkReplyJob.perform_later(account.id)

    redirect_to account_path, notice: t("whatsapp.link.success")
  end

  private

    def find_pending_account
      @account = WhatsappAccount.find_by(link_token: params[:token].to_s)

      return if @account.present? && @account.link_token_valid?

      redirect_to account_path, alert: t("whatsapp.link.failure")
    end

    def broadcast_consent?
      ActiveModel::Type::Boolean.new.cast(params[:broadcast_consent]).present?
    end
end
