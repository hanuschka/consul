module Adm
  class WhatsappDialogsController < Adm::BaseController
    MESSAGE_LIMIT = 200

    before_action :authorize_settings
    before_action :load_account

    def show
      @conversation = @account.whatsapp_conversation
      @message_count = @account.whatsapp_messages.count
      @messages = recent_messages
      @message_days = @messages.group_by { |message| message.created_at.to_date }
      @service_window_open = service_window_open?

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.whatsapp.show.title"), url: adm_whatsapp_path(tab: "dialogs") },
        { name: @account.contact_label }
      ]
    end

    def reply
      body = params.dig(:reply, :body).to_s.strip

      if body.blank?
        flash[:error] = t("adm.whatsapp.dialogs.reply_blank")

        return redirect_to adm_whatsapp_dialog_path(@account)
      end

      message = ::Whatsapp::Outbound.text(account: @account, body: body)

      if message.blank?
        flash[:error] = t("adm.whatsapp.dialogs.reply_window_closed")
      elsif message.status == "sent"
        flash[:success] = t("adm.whatsapp.dialogs.reply_sent")
      else
        flash[:error] = t("adm.whatsapp.dialogs.reply_failed", error: message.error.to_s.truncate(200))
      end

      redirect_to adm_whatsapp_dialog_path(@account)
    end

    private

      def authorize_settings
        authorize [:adm, Setting], :update?
      end

      def load_account
        @account = WhatsappAccount.find(params[:id])
      end

      def recent_messages
        @account
          .whatsapp_messages
          .order(created_at: :desc)
          .limit(MESSAGE_LIMIT)
          .to_a
          .reverse
      end

      def service_window_open?
        ::Whatsapp::ServiceWindow.open?(@account)
      end
  end
end
