module PdfServices
  class BudgetInvestmentExporter < PdfServices::BaseService
    COLORS = {
      heading: "1a1a2e",
      subheading: "444444",
      label: "666666",
      text: "333333",
      border: "dddddd",
      light_bg: "f5f7fa",
      accent: "2b5797"
    }.freeze

    def initialize(investment, projekt_phase)
      @investment = investment
      @projekt_phase = projekt_phase
      @budget = investment.budget
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [40, 50, 40, 50]) do |pdf|
        setup_fonts(pdf)
        render_header(pdf)
        render_meta_bar(pdf)
        render_description(pdf)
        render_image(pdf)
        render_map(pdf)
        render_additional_fields(pdf)
        render_admin_status(pdf)
        render_footer(pdf)
      end
    end

    private

      def setup_fonts(pdf)
        pdf.font_families.update(
          "Helvetica" => {
            normal: "Helvetica",
            bold: "Helvetica-Bold",
            italic: "Helvetica-Oblique"
          }
        )
        pdf.font "Helvetica"
        pdf.default_leading 3
      end

      def render_header(pdf)
        # Project & phase context
        pdf.fill_color COLORS[:subheading]
        pdf.text "#{@projekt_phase.projekt.page.title} — #{@projekt_phase.title}", size: 9

        pdf.move_down 6

        # Title
        pdf.fill_color COLORS[:heading]
        pdf.text @investment.title, size: 18, style: :bold

        pdf.move_down 4

        # ID
        pdf.fill_color COLORS[:label]
        pdf.text "##{@investment.id}", size: 9

        pdf.move_down 12
        draw_divider(pdf)
        pdf.move_down 12
      end

      def render_meta_bar(pdf)
        meta_items = []
        meta_items << ["Autor", @investment.author.username]
        meta_items << ["Eingereicht", I18n.l(@investment.created_at.to_date)]
        meta_items << ["Unterstützung", @investment.total_votes.to_s]

        if @investment.feasibility.present? && @investment.feasibility != "undecided"
          meta_items << ["Kriterien", Budget::Investment.human_attribute_name("feasibility_#{@investment.feasibility}")]
        end

        if @budget.show_money? && @investment.price.present? && @investment.price > 0
          meta_items << ["Preis", @investment.formatted_price]
        end

        if @investment.selected?
          meta_items << ["Ausgewählt", "Ja"]
        end

        if @investment.winner?
          meta_items << ["Gewinner", "Ja"]
        end

        meta_items.each_slice(3) do |row|
          row.each_with_index do |item, i|
            x = i * 170
            pdf.bounding_box([x, pdf.cursor], width: 160) do
              pdf.fill_color COLORS[:label]
              pdf.text item[0], size: 8
              pdf.fill_color COLORS[:text]
              pdf.text item[1], size: 10, style: :bold
            end
          end
          pdf.move_down 8
        end

        pdf.move_down 8
        draw_divider(pdf)
        pdf.move_down 12
      end

      def render_description(pdf)
        pdf.fill_color COLORS[:heading]
        pdf.text "Beschreibung", size: 12, style: :bold
        pdf.move_down 6

        pdf.fill_color COLORS[:text]
        description_text = html_to_paragraphs(@investment.description)
        if description_text.present?
          pdf.text description_text, size: 10, inline_format: true
        end

        pdf.move_down 12
      end

      def render_image(pdf)
        return unless @investment.image&.attachment&.attached?

        begin
          image_data = StringIO.new(@investment.image.attachment.download)
          pdf.image(image_data, width: [pdf.bounds.width, 400].min, position: :left)
          pdf.move_down 12
        rescue StandardError
          # Skip image if it can't be rendered
        end
      end

      def render_map(pdf)
        return unless @investment&.map_location&.screenshot&.attached?

        begin
          image_data = StringIO.new(@investment.map_location.screenshot.download)
          pdf.image(image_data, width: [pdf.bounds.width, 400].min, position: :left)
          pdf.move_down 12
        rescue StandardError
          # Skip map if it can't be rendered
        end
      end

      def render_additional_fields(pdf)
        rows = []

        if @investment.on_behalf_of.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.on_behalf_of"), @investment.on_behalf_of]
        end

        if @projekt_phase.feature?("form.enable_external_video") && @investment.video_url.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.video_url"), @investment.video_url]
        end

        if @projekt_phase.feature?("form.show_implementation_option_fields")
          if @investment.implementation_performer.present?
            rows << [
              I18n.t("adm.projekts.budget_investments.show.implementation_performer"),
              I18n.t("adm.attribute_editor.budget/investment.implementation_performer_label_options.#{@investment.implementation_performer}")
            ]
          end

          if @investment.implementation_contribution.present?
            rows << [I18n.t("adm.projekts.budget_investments.show.implementation_contribution"), @investment.implementation_contribution]
          end
        end

        if @projekt_phase.feature?("form.show_user_cost_estimate") && @investment.user_cost_estimate.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.user_cost_estimate"), @investment.user_cost_estimate.to_s]
        end

        if @projekt_phase.feature?("form.labels") && @investment.projekt_labels.any?
          rows << [
            @projekt_phase.projekt_labels_label_text,
            @investment.projekt_labels.map(&:name).join(", ")
          ]
        end

        if @projekt_phase.feature?("form.sentiments") && @investment.sentiment.present?
          rows << [@projekt_phase.sentiment_label_text, @investment.sentiment.name]
        end

        if @projekt_phase.feature?("form.allow_attached_documents") && @investment.documents.any?
          rows << [
            I18n.t("adm.projekts.budget_investments.show.documents"),
            @investment.documents.map(&:title).join(", ")
          ]
        end

        return if rows.empty?

        draw_divider(pdf)
        pdf.move_down 12

        rows.each do |label, value|
          pdf.fill_color COLORS[:label]
          pdf.text label, size: 8
          pdf.fill_color COLORS[:text]
          pdf.text value.to_s, size: 10
          pdf.move_down 8
        end

        pdf.move_down 4
      end

      def render_admin_status(pdf)
        draw_divider(pdf)
        pdf.move_down 12

        pdf.fill_color COLORS[:heading]
        pdf.text "Bewertung", size: 12, style: :bold
        pdf.move_down 6

        status_rows = []
        status_rows << ["Kriterien", Budget::Investment.human_attribute_name("feasibility_#{@investment.feasibility}")]
        status_rows << ["Bewertung beendet", @investment.valuation_finished? ? "Ja" : "Nein"]

        if @investment.valuator_explanation.present?
          status_rows << ["Begründung", html_to_paragraphs(@investment.valuator_explanation.to_s)]
        end

        if @budget.show_money?
          status_rows << ["Preis", @investment.price.present? && @investment.price > 0 ? @investment.formatted_price : "–"]
        end

        status_rows << ["Ausgewählt", @investment.selected? ? "Ja" : "Nein"]
        status_rows << ["Gewinner", @investment.winner? ? "Ja" : "Nein"]

        status_rows.each do |label, value|
          pdf.fill_color COLORS[:label]
          pdf.text label, size: 8
          pdf.fill_color COLORS[:text]
          pdf.text value.to_s, size: 10
          pdf.move_down 6
        end
      end

      def render_footer(pdf)
        pdf.move_down 20
        draw_divider(pdf)
        pdf.move_down 8

        pdf.fill_color COLORS[:label]
        pdf.text "Erstellt am #{I18n.l(Time.zone.today)} — #{@projekt_phase.projekt.page.title}", size: 7, align: :right
      end

      def draw_divider(pdf)
        pdf.stroke_color COLORS[:border]
        pdf.line_width = 0.5
        pdf.stroke_horizontal_rule
      end
  end
end
