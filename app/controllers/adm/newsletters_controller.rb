module Adm
  class NewslettersController < Adm::BaseController
    include ImageAttributes

    def index
      authorize [:adm, :newsletter]
      @pagy, @newsletters = pagy(
        policy_scope([:adm, Newsletter]).order(created_at: :desc)
      )

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters") }
      ]
    end

    def show
      @newsletter = Newsletter.find(params[:id])
      authorize [:adm, @newsletter]
      @recipients_count = @newsletter.list_of_recipient_emails&.count || 0

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: @newsletter.subject }
      ]
    end

    def new
      @newsletter = Newsletter.new
      authorize [:adm, @newsletter]

      @projekt = Projekt.find(params[:projekt_id]) if params[:projekt_id]
      prefill_newsletter_from_projekt if @projekt.present?

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t(".title") }
      ]
    end

    def create
      @newsletter = Newsletter.new(newsletter_params)
      authorize [:adm, @newsletter]

      if @newsletter.save
        redirect_to edit_adm_newsletter_path(@newsletter), notice: t(".success")
      else
        @breadcrumbs = [
          { name: t("adm.menu.items.notifications"), icon: "send" },
          { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
          { name: t("adm.newsletters.new.title") }
        ]
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @newsletter = Newsletter.find(params[:id])
      authorize [:adm, @newsletter]
      @newsletter_image = @newsletter.image
      unless @newsletter_image
        @newsletter_image = @newsletter.build_image(user: current_user)
        @newsletter_image.save!(validate: false)
      end

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: @newsletter.subject }
      ]
    end

    def update
      @newsletter = Newsletter.find(params[:id])
      authorize [:adm, @newsletter]

      if @newsletter.update(newsletter_params)
        redirect_to adm_newsletter_path(@newsletter), notice: t(".success")
      else
        @breadcrumbs = [
          { name: t("adm.menu.items.notifications"), icon: "send" },
          { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
          { name: t("adm.newsletters.edit.title") }
        ]
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @newsletter = Newsletter.find(params[:id])
      authorize [:adm, @newsletter]

      @newsletter.destroy!
      redirect_to adm_newsletters_path, notice: t(".success")
    end

    def deliver
      @newsletter = Newsletter.find(params[:id])
      authorize [:adm, @newsletter]

      if @newsletter.valid?
        @newsletter.delay.deliver
        @newsletter.update!(sent_at: Time.current)
        redirect_to adm_newsletter_path(@newsletter), notice: t("adm.newsletters.show.deliver_success")
      else
        redirect_to adm_newsletter_path(@newsletter), alert: t("admin.segment_recipient.invalid_recipients_segment")
      end
    end

    def send_test
      @newsletter = Newsletter.find(params[:id])
      authorize [:adm, @newsletter]

      Mailer.newsletter(@newsletter, current_user.email).deliver_now
      redirect_to adm_newsletter_path(@newsletter), notice: t("adm.newsletters.show.send_test_success")
    end

    def settings
      authorize [:adm, :newsletter]

      @breadcrumbs = [
        { name: t("adm.menu.items.notifications"), icon: "send" },
        { name: t("adm.menu.items.notifications_subitems.newsletters"), url: adm_newsletters_path },
        { name: t("adm.newsletters.settings.title") }
      ]
    end

    private

      def newsletter_params
        params.require(:newsletter).permit(
          :subject, :recipient_group_id, :from, :body, :title, :subtitle,
          :greeting, :title_color, :subtitle_color,
          image_attributes: image_attributes
        )
      end

      def prefill_newsletter_from_projekt
        @newsletter.subject = t("custom.newsletters.new_projekt.subject", title: @projekt.title)
        @newsletter.from = Setting["mailer_from_address"]
        @newsletter.segment_recipient = "newsletter_subscribers"
        @newsletter.body = newsletter_body
      end

      def newsletter_body
        body = ""
        body += "<h3>#{@projekt.title}</h3>" if @projekt.title
        body += "<p>#{@projekt.description}</p>" if @projekt.page.subtitle
        body += "<p><img src='#{url_for(@projekt.image.variant(:large))}'></p>" if @projekt.image

        if @projekt.total_duration_start.present?
          body += "<p><strong>#{t("custom.newsletters.new_projekt.total_duration_start")}:</strong> #{l(@projekt.total_duration_start, format: "%d. %B %Y")}</p>"
        end

        if @projekt.total_duration_end.present?
          body += "<p><strong>#{t("custom.newsletters.new_projekt.total_duration_end")}:</strong> #{t("custom.newsletters.new_projekt.total_duration_end_till")} #{l(@projekt.total_duration_end, format: "%d. %B %Y")}</p>"
        end

        body += "<p><strong>#{t("custom.newsletters.new_projekt.open_phases")}:</strong></p>"
        body += "<ul style='margin-bottom:30px;'>#{open_phases_for_body}</ul>"

        body += "<p style='margin-bottom:30px;'>"
        body += "<a href='#{page_url(@projekt.page.slug)}' style='background:#004a83;padding:0.75rem 1.5rem;color:#fff;border-radius:4px;margin-right:20px;display:inline-block;margin-bottom:15px;'>#{t("custom.newsletters.new_projekt.url")}</a>"
        body += "<a href='#{page_url(@projekt.page.slug)}#filter-subnav' style='background:#004a83;padding:0.75rem 1.5rem;color:#fff;border-radius:4px;display:inline-block;'>#{t("custom.newsletters.new_projekt.url_participate")}</a>"
        body += "</p>"

        body += "<p></p>"
        body
      end

      def open_phases_for_body
        @projekt.projekt_phases.where(projekt_phases: { active: true }).sorted.map do |phase|
          date_range = helpers.format_date_range(phase.start_date, phase.end_date)
          if date_range.present?
            "<li>#{phase.title} (#{helpers.format_date_range(phase.start_date, phase.end_date)})</li>"
          else
            "<li>#{phase.title}</li>"
          end
        end.join
      end
  end
end
