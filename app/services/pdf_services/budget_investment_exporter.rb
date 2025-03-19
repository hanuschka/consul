module PdfServices
  class BudgetInvestmentExporter < PdfServices::BaseService
    def initialize(investment)
      @investment = investment
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 30) do |pdf|
        pdf.text @investment.title, size: 20, style: :bold

        pdf.move_down 10

        pdf.formatted_text [
          { text: "Erstellt am: ", size: 10, styles: [:bold] },
          { text: @investment.created_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.formatted_text [
          { text: "Aktualisiert am: ", size: 10, styles: [:bold] },
          { text: @investment.updated_at.strftime("%d %b %Y"), size: 10 }
        ]

        pdf.move_down 10

        if @investment.approximated_address.present?
          pdf.formatted_text [
            { text: "#{Budget::Investment.human_attribute_name(:approximated_address)}: ", size: 10, styles: [:bold] },
            { text: @investment.approximated_address, size: 10 }
          ]
        end

        pdf.move_down 10

        if @investment&.map_location&.screenshot.present?
          image_data = StringIO.open(@investment.map_location.screenshot.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 10

        if @investment.image.present?
          image_data = StringIO.open(@investment.image.attachment.download)
          pdf.image(image_data, width: 500)
        end

        pdf.move_down 20

        pdf.text html_to_paragraphs(@investment.description), size: 10, inline_format: true

        pdf.move_down 10
      end
    end
  end
end
