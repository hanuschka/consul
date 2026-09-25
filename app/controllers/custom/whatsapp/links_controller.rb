class Whatsapp::LinksController < ApplicationController
  include Whatsapp::FeatureGated

  before_action :authenticate_user!
  before_action :find_pending_account

  skip_authorization_check

  def show
    @token = params[:token]
  end

  def create
    result =
      ::Whatsapp::Accounts::ConfirmLinkService.call(
        token: params[:token],
        user: current_user,
        broadcast_consent: broadcast_consent?
      )

    # The bot is told either way: a citizen who just failed to link is looking
    # at the chat, and the catalog's A5/A6 branches are what tell them why and
    # what to do next.
    ::Whatsapp::ConfirmLinkReplyJob.perform_later(@account.id, outcome_for(result))

    if !result.success?
      return redirect_to account_path, alert: t("whatsapp.link.#{result.error}")
    end

    redirect_to account_path, notice: t("whatsapp.link.success")
  end

  private

    def find_pending_account
      @account = Whatsapp::Account.find_by(link_token: params[:token].to_s)

      return if @account.present? && @account.link_token_valid?

      redirect_to account_path, alert: t("whatsapp.link.failure")
    end

    def broadcast_consent?
      ActiveModel::Type::Boolean.new.cast(params[:broadcast_consent]).present?
    end

    def outcome_for(result)
      return "linked" if result.success?

      result.error.to_s
    end
end
