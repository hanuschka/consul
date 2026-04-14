module PdfServices
  class BudgetInvestmentExporter < PdfServices::BaseService
    def initialize(investment, projekt_phase = nil)
      @investment = investment
      @projekt_phase = projekt_phase || investment.budget&.projekt_phase
      @budget = investment.budget
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [0, 0, 30, 0]) do |pdf|
        setup_fonts(pdf)
        render_header_banner(pdf, title_text: "#{@investment.title} (#{@investment.id})")
        pdf.bounding_box([40, pdf.cursor], width: pdf.bounds.width - 80) do
          render_meta_card(pdf, meta_rows)
          render_title_and_description(pdf, title: @investment.title, description_html: @investment.description)
          render_additional_fields(pdf)
          render_admin_status(pdf)
          render_attachment_image(pdf, @investment.image)
          render_map_image(pdf, @investment.map_location)
        end
        render_footer(pdf)
      end
    end

    private

      def meta_rows
        rows = [
          [I18n.t("adm.projekts.budget_investments.show.author", default: "Autor"), @investment.author.username],
          [I18n.t("adm.projekts.budget_investments.show.created_at", default: "Eingereicht"), I18n.l(@investment.created_at, format: :long)],
          [I18n.t("adm.projekts.budget_investments.show.supports", default: "Unterstützung"), @investment.total_votes.to_s]
        ]

        if @projekt_phase.present?
          rows.unshift([I18n.t("adm.projekts.budget_investments.show.projekt", default: "Projekt"), "#{@projekt_phase.projekt.page.title} — #{@projekt_phase.title}"])
        end

        if @investment.feasibility.present? && @investment.feasibility != "undecided"
          rows << [I18n.t("adm.projekts.budget_investments.show.feasibility", default: "Kriterien"), Budget::Investment.human_attribute_name("feasibility_#{@investment.feasibility}")]
        end

        if @budget&.show_money? && @investment.price.present? && @investment.price > 0
          rows << [I18n.t("adm.projekts.budget_investments.show.price", default: "Preis"), @investment.formatted_price]
        end

        rows << [I18n.t("adm.projekts.budget_investments.show.selected", default: "Ausgewählt"), "Ja"] if @investment.selected?
        rows << [I18n.t("adm.projekts.budget_investments.show.winner", default: "Gewinner"), "Ja"] if @investment.winner?

        rows
      end

      def render_additional_fields(pdf)
        rows = []

        if @investment.on_behalf_of.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.on_behalf_of", default: "Im Namen von"), @investment.on_behalf_of]
        end

        if @projekt_phase&.feature?("form.enable_external_video") && @investment.video_url.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.video_url", default: "Video"), @investment.video_url]
        end

        if @projekt_phase&.feature?("form.show_implementation_option_fields")
          if @investment.implementation_performer.present?
            rows << [
              I18n.t("adm.projekts.budget_investments.show.implementation_performer", default: "Umsetzung durch"),
              I18n.t("adm.attribute_editor.budget/investment.implementation_performer_label_options.#{@investment.implementation_performer}", default: @investment.implementation_performer)
            ]
          end

          if @investment.implementation_contribution.present?
            rows << [I18n.t("adm.projekts.budget_investments.show.implementation_contribution", default: "Eigenbeitrag"), @investment.implementation_contribution]
          end
        end

        if @projekt_phase&.feature?("form.show_user_cost_estimate") && @investment.user_cost_estimate.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.user_cost_estimate", default: "Kostenschätzung"), @investment.user_cost_estimate.to_s]
        end

        if @projekt_phase&.feature?("form.labels") && @investment.projekt_labels.any?
          rows << [@projekt_phase.projekt_labels_label_text, @investment.projekt_labels.map(&:name).join(", ")]
        end

        if @projekt_phase&.feature?("form.sentiments") && @investment.sentiment.present?
          rows << [@projekt_phase.sentiment_label_text, @investment.sentiment.name]
        end

        render_labeled_rows(pdf, rows)
      end

      def render_admin_status(pdf)
        pdf.stroke_color COLORS[:border]
        pdf.stroke_horizontal_rule
        pdf.move_down 12

        pdf.text I18n.t("adm.projekts.budget_investments.show.valuation_title", default: "Bewertung"), size: 12, style: :bold, color: COLORS[:accent]
        pdf.move_down 6

        rows = [
          [I18n.t("adm.projekts.budget_investments.show.feasibility", default: "Kriterien"), Budget::Investment.human_attribute_name("feasibility_#{@investment.feasibility}")],
          [I18n.t("adm.projekts.budget_investments.show.valuation_finished", default: "Bewertung beendet"), @investment.valuation_finished? ? "Ja" : "Nein"]
        ]

        if @investment.valuator_explanation.present?
          rows << [I18n.t("adm.projekts.budget_investments.show.explanation", default: "Begründung"), html_to_paragraphs(@investment.valuator_explanation.to_s)]
        end

        if @budget&.show_money?
          price_text = @investment.price.present? && @investment.price > 0 ? @investment.formatted_price : "–"
          rows << [I18n.t("adm.projekts.budget_investments.show.price", default: "Preis"), price_text]
        end

        rows << [I18n.t("adm.projekts.budget_investments.show.selected", default: "Ausgewählt"), @investment.selected? ? "Ja" : "Nein"]
        rows << [I18n.t("adm.projekts.budget_investments.show.winner", default: "Gewinner"), @investment.winner? ? "Ja" : "Nein"]

        render_labeled_rows(pdf, rows)
        pdf.move_down 4
      end
  end
end
