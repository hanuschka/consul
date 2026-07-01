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

      if @newsletter.draft?
        ::Newsletters::MigrateBodyToContentBlocks.call(@newsletter)
      end

      @content_blocks = @newsletter.content_blocks

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

      if @newsletter.draft? && @newsletter.content_blocks.none? && @newsletter.body.blank?
        redirect_to adm_newsletter_path(@newsletter), alert: t("adm.newsletters.show.deliver_no_content")

        return
      end

      @newsletter.snapshot_content_blocks_to_body!

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
          :greeting, :title_color, :subtitle_color, :respect_newsletter_optout,
          image_attributes: image_attributes
        )
      end

      def prefill_newsletter_from_projekt
        @newsletter.subject = t("custom.newsletters.new_projekt.subject", title: @projekt.title)
        @newsletter.from = Setting["mailer_from_address"]
        @newsletter.segment_recipient = "newsletter_subscribers"
        @newsletter.recipient_group = default_recipient_group_for_prefill
        @newsletter.body = newsletter_body
      end

      def default_recipient_group_for_prefill
        RecipientGroup.find_by(access_method: "all_newsletter_subscriber_ids") ||
          RecipientGroup.order(:id).first
      end

      def newsletter_body
        brand = Setting.newsletter_brand_color
        text_color = "#333333"
        muted_color = "#666666"
        font = "Arial, Helvetica, sans-serif"
        content_width = 590

        sections = [
          newsletter_section_intro(font: font, color: text_color),
          newsletter_section_image(width: content_width),
          newsletter_section_title(font: font, color: brand),
          newsletter_section_description(font: font, color: text_color),
          newsletter_section_meta(font: font, label_color: brand, text_color: text_color, divider_color: brand),
          newsletter_section_phases(font: font, label_color: brand, text_color: text_color, divider_color: brand),
          newsletter_section_cta(font: font, brand: brand)
        ].compact.reject(&:blank?)

        <<~HTML
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;font-family:#{font};color:#{text_color};">
            <tr>
              <td align="left" style="padding:0;font-family:#{font};font-size:15px;line-height:1.5;color:#{text_color};">
                #{sections.join("\n")}
              </td>
            </tr>
          </table>
        HTML
      end

      def newsletter_section_intro(font:, color:)
        intro = t("custom.newsletters.new_projekt.intro", default: "")
        return nil if intro.blank?

        %(<p style="margin:0 0 20px 0;padding:0;font-family:#{font};font-size:15px;line-height:1.5;color:#{color};">#{ERB::Util.h(intro)}</p>)
      end

      def newsletter_section_image(width:)
        return nil unless @projekt.image

        src = url_for(@projekt.image.variant(:large))
        <<~HTML
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 24px 0;">
            <tr>
              <td align="center" style="padding:0;">
                <img src="#{src}" alt="#{ERB::Util.h(@projekt.title.to_s)}" width="#{width}" style="display:block;width:100%;max-width:#{width}px;height:auto;border:0;outline:none;text-decoration:none;" />
              </td>
            </tr>
          </table>
        HTML
      end

      def newsletter_section_title(font:, color:)
        return nil if @projekt.title.blank?

        %(<h2 style="margin:0 0 16px 0;padding:0;font-family:#{font};font-size:24px;line-height:1.3;font-weight:bold;color:#{color};">#{ERB::Util.h(@projekt.title)}</h2>)
      end

      def newsletter_section_description(font:, color:)
        description = @projekt.description.to_s
        return nil if description.blank?

        %(<div style="margin:0 0 24px 0;padding:0;font-family:#{font};font-size:15px;line-height:1.6;color:#{color};">#{helpers.sanitize(helpers.simple_format(description))}</div>)
      end

      def newsletter_section_meta(font:, label_color:, text_color:, divider_color:)
        rows = []

        if @projekt.total_duration_start.present?
          rows << meta_row(
            label: t("custom.newsletters.new_projekt.total_duration_start"),
            value: l(@projekt.total_duration_start.to_date, format: "%d. %B %Y"),
            font: font, label_color: label_color, text_color: text_color
          )
        end

        if @projekt.total_duration_end.present?
          rows << meta_row(
            label: t("custom.newsletters.new_projekt.total_duration_end"),
            value: "#{t("custom.newsletters.new_projekt.total_duration_end_till")} #{l(@projekt.total_duration_end.to_date, format: "%d. %B %Y")}",
            font: font, label_color: label_color, text_color: text_color
          )
        end

        return nil if rows.empty?

        <<~HTML
          #{newsletter_divider(color: divider_color)}
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 20px 0;">
            #{rows.join("\n")}
          </table>
        HTML
      end

      def meta_row(label:, value:, font:, label_color:, text_color:)
        <<~HTML
          <tr>
            <td style="padding:4px 0;font-family:#{font};font-size:15px;line-height:1.5;color:#{text_color};">
              <strong style="color:#{label_color};">#{ERB::Util.h(label)}:</strong> #{ERB::Util.h(value)}
            </td>
          </tr>
        HTML
      end

      def newsletter_section_phases(font:, label_color:, text_color:, divider_color:)
        phases = @projekt.projekt_phases.where(projekt_phases: { active: true }).sorted.to_a
        return nil if phases.empty?

        rows = phases.map { |phase| phase_row(phase, font: font, text_color: text_color, label_color: label_color) }

        <<~HTML
          #{newsletter_divider(color: divider_color)}
          <p style="margin:0 0 12px 0;padding:0;font-family:#{font};font-size:15px;line-height:1.5;color:#{label_color};">
            <strong>#{ERB::Util.h(t("custom.newsletters.new_projekt.open_phases"))}:</strong>
          </p>
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 28px 0;">
            #{rows.join("\n")}
          </table>
        HTML
      end

      def phase_row(phase, font:, text_color:, label_color:)
        date_range = helpers.format_date_range(phase.start_date, phase.end_date).to_s.strip
        line = if date_range.present?
                 "#{ERB::Util.h(phase.title)} <span style=\"color:#{text_color};\">(#{ERB::Util.h(date_range)})</span>"
               else
                 ERB::Util.h(phase.title).to_s
               end

        <<~HTML
          <tr>
            <td width="16" valign="top" align="left" style="padding:4px 0;font-family:#{font};font-size:15px;line-height:1.5;color:#{label_color};">
              &bull;&nbsp;
            </td>
            <td valign="top" align="left" style="padding:4px 0;font-family:#{font};font-size:15px;line-height:1.5;color:#{text_color};">
              #{line}
            </td>
          </tr>
        HTML
      end

      def newsletter_section_cta(font:, brand:)
        url = page_url(@projekt.page.slug)
        participate_url = "#{url}#filter-subnav"

        <<~HTML
          <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 16px 0;">
            <tr>
              <td align="left" style="padding:0 0 12px 0;">
                #{button_primary(url: url, label: t("custom.newsletters.new_projekt.url"), font: font, brand: brand)}
              </td>
            </tr>
            <tr>
              <td align="left" style="padding:0;">
                #{button_secondary(url: participate_url, label: t("custom.newsletters.new_projekt.url_participate"), font: font, brand: brand)}
              </td>
            </tr>
          </table>
        HTML
      end

      def button_primary(url:, label:, font:, brand:)
        <<~HTML
          <table border="0" cellpadding="0" cellspacing="0" style="border-collapse:separate;">
            <tr>
              <td align="center" style="background-color:#{brand};border-radius:4px;padding:12px 28px;mso-padding-alt:12px 28px;">
                <a href="#{url}" target="_blank" style="color:#ffffff;text-decoration:none;font-family:#{font};font-size:15px;font-weight:bold;line-height:1;display:inline-block;">#{ERB::Util.h(label)}</a>
              </td>
            </tr>
          </table>
        HTML
      end

      def button_secondary(url:, label:, font:, brand:)
        <<~HTML
          <table border="0" cellpadding="0" cellspacing="0" style="border-collapse:separate;">
            <tr>
              <td align="center" style="background-color:#ffffff;border:2px solid #{brand};border-radius:4px;padding:10px 26px;mso-padding-alt:10px 26px;">
                <a href="#{url}" target="_blank" style="color:#{brand};text-decoration:none;font-family:#{font};font-size:15px;font-weight:bold;line-height:1;display:inline-block;">#{ERB::Util.h(label)}</a>
              </td>
            </tr>
          </table>
        HTML
      end

      def newsletter_divider(color:)
        %(<table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:8px 0 16px 0;"><tr><td height="1" style="font-size:0;line-height:0;background-color:#{color};border-top:1px solid #{color};">&nbsp;</td></tr></table>)
      end
  end
end
