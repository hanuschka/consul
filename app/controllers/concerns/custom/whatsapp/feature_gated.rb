module Whatsapp::FeatureGated
  extend ActiveSupport::Concern

  included do
    before_action :ensure_whatsapp_enabled!
  end

  private

    # A portal with the bot switched off, or with credentials missing, has no
    # linking or subscription page to show — the tokens those pages take were
    # only ever handed out by the bot.
    def ensure_whatsapp_enabled!
      return if ::Whatsapp.enabled?

      redirect_to root_path
    end
end
