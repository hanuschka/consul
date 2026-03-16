module Adm
  class UnregisteredNewsletterSubscribersController < Adm::BaseController
    def index
      authorize [:adm, :unregistered_newsletter_subscriber]
      @pagy, @unregistered_newsletter_subscribers = pagy(
        policy_scope([:adm, UnregisteredNewsletterSubscriber]).order(created_at: :desc),
        items: 25
      )

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.index.tabs.unregistered_subscribers") }
      ]

      respond_to do |format|
        format.html
        format.csv do
          send_data CsvServices::UnregisteredNewsletterSubscribersExporter.call(
            UnregisteredNewsletterSubscriber.all
          ), filename: "unregistered-newsletter-subscribers-#{Time.zone.today}.csv"
        end
      end
    end

    def destroy
      @subscriber = UnregisteredNewsletterSubscriber.find(params[:id])
      authorize [:adm, @subscriber]

      @subscriber.destroy!
      redirect_to adm_unregistered_newsletter_subscribers_path, notice: t(".success")
    end
  end
end
