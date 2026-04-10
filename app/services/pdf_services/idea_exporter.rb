module PdfServices
  class IdeaExporter < PdfServices::BaseService
    def initialize(idea, host)
      @idea = idea
      @host = host
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [0, 0, 30, 0]) do |pdf|
        setup_fonts(pdf)
        render_header_banner(pdf, title_text: "#{@idea.title} (#{@idea.id})", qr_url: record_url)
        pdf.bounding_box([40, pdf.cursor], width: pdf.bounds.width - 80) do
          render_meta_card(pdf, meta_rows)
          render_title_and_description(pdf, title: @idea.title, description_html: @idea.description)
          render_map_image(pdf, @idea.map_location)
          render_attachment_image(pdf, @idea.image)
        end
        render_footer(pdf)
      end
    end

    private

      def meta_rows
        rows = [
          [I18n.t("custom.admin.ideas.show.created_at"), I18n.l(@idea.created_at, format: :long)],
          [I18n.t("custom.admin.ideas.show.updated_at"), I18n.l(@idea.updated_at, format: :long)],
          [I18n.t("custom.admin.ideas.show.status"), I18n.t("ideas.status.#{@idea.status}")]
        ]

        if @idea.admin_accepted_at.present?
          rows << [I18n.t("custom.admin.ideas.show.admin_accepted_at"), I18n.l(@idea.admin_accepted_at, format: :long)]
        end

        rows << [I18n.t("custom.admin.ideas.show.category"), @idea.category.name] if @idea.category.present?

        if @idea.approximated_address.present?
          rows << [Idea.human_attribute_name(:approximated_address), @idea.approximated_address]
        end

        rows << ["Link", record_url]

        rows
      end

      def record_url
        Rails.application.routes.url_helpers.idea_url(@idea, host: @host)
      end
  end
end
