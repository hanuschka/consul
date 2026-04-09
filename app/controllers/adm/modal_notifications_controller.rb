module Adm
  class ModalNotificationsController < Adm::BaseController
    def index
      authorize [:adm, :modal_notification]
      @pagy, @modal_notifications = pagy(
        policy_scope([:adm, ModalNotification]).order(created_at: :desc)
      )

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.modal_notifications") }
      ]
    end

    def new
      @modal_notification = ModalNotification.new
      authorize [:adm, @modal_notification]

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.modal_notifications"), url: adm_modal_notifications_path },
        { name: t(".title") }
      ]
    end

    def edit
      @modal_notification = ModalNotification.find(params[:id])
      authorize [:adm, @modal_notification]

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.modal_notifications"), url: adm_modal_notifications_path },
        { name: t(".title") }
      ]
    end

    def create
      @modal_notification = ModalNotification.new(modal_notification_params)
      authorize [:adm, @modal_notification]

      if @modal_notification.save
        redirect_to adm_modal_notifications_path, notice: t(".success")
      else
        @breadcrumbs = [
          { name: t("adm.menu.items.notifications"), icon: "send" },
          { name: t("adm.menu.items.notifications_subitems.modal_notifications"), url: adm_modal_notifications_path },
          { name: t("adm.modal_notifications.new.title") }
        ]
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @modal_notification = ModalNotification.find(params[:id])
      authorize [:adm, @modal_notification]

      if @modal_notification.update(modal_notification_params)
        redirect_to adm_modal_notifications_path, notice: t(".success")
      else
        @breadcrumbs = [
          { name: t("adm.menu.items.notifications"), icon: "send" },
          { name: t("adm.menu.items.notifications_subitems.modal_notifications"), url: adm_modal_notifications_path },
          { name: t("adm.modal_notifications.edit.title") }
        ]
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @modal_notification = ModalNotification.find(params[:id])
      authorize [:adm, @modal_notification]

      @modal_notification.destroy!
      redirect_to adm_modal_notifications_path, notice: t(".success")
    end

    private

      def modal_notification_params
        params.require(:modal_notification).permit(:active_from, :active_to, :title, :html_content)
      end
  end
end
