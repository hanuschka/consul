module PdfServices
  class IdeaExporter < PdfServices::BaseService
    def initialize(idea, host)
      @idea = idea
      @host = host
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 30) do |pdf|
        pdf.text @idea.title, size: 20, style: :bold

        pdf.move_down 10

        pdf.formatted_text [
          { text: "ID: ", size: 10, styles: [:bold] },
          { text: @idea.id.to_s, size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.ideas.show.created_at")}: ", size: 10, styles: [:bold] },
          { text: @idea.created_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.ideas.show.updated_at")}: ", size: 10, styles: [:bold] },
          { text: @idea.updated_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.ideas.show.admin_accepted_at")}: ", size: 10, styles: [:bold] },
          { text: @idea.admin_accepted_at&.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.ideas.show.status")}: ", size: 10, styles: [:bold] },
          { text: @idea.status, size: 10 }
        ]

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.ideas.show.category")}: ", size: 10, styles: [:bold] },
          { text: @idea.category&.name, size: 10 }
        ]

        pdf.move_down 10

        pdf.svg(svg, at: [pdf.bounds.left + 500 - 80, pdf.bounds.top - 30], width: 80)

        pdf.move_down 10

        if @idea.approximated_address.present?
          pdf.formatted_text [
            { text: "#{Idea.human_attribute_name(:approximated_address)}: ", size: 10, styles: [:bold] },
            { text: @idea.approximated_address, size: 10 }
          ]
        end

        pdf.move_down 10

        pdf.formatted_text [
          { text: "#{I18n.t("custom.admin.ideas.show.link")}: ", size: 10, styles: [:bold] },
          { text: idea_url, size: 10, link: idea_url }
        ]

        pdf.move_down 10

        if @idea&.map_location&.screenshot.present?
          image_data = StringIO.open(@idea.map_location.screenshot.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 10

        if @idea.image.present?
          image_data = StringIO.open(@idea.image.attachment.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 20

        pdf.text html_to_paragraphs(@idea.description), size: 10, inline_format: true

        pdf.move_down 10
      end
    end

    private

      def idea_url
        Rails.application.routes.url_helpers.idea_url(@idea, host: @host)
      end

      def svg
        qrcode = RQRCode::QRCode.new(idea_url)

        qrcode.as_svg(
          module_size: 80,
          standalone: true,
          use_path: true
        )
      end
  end
end
