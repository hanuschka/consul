module PdfServices
  class ProposalExporter < PdfServices::BaseService
    def initialize(proposal, host)
      @proposal = proposal
      @host = host
      @projekt_phase = proposal.projekt_phase
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: [0, 0, 30, 0]) do |pdf|
        setup_fonts(pdf)
        render_header_banner(pdf, title_text: "#{@proposal.title} (#{@proposal.id})", qr_url: record_url)
        pdf.bounding_box([40, pdf.cursor], width: pdf.bounds.width - 80) do
          render_meta_card(pdf, meta_rows)
          render_title_and_description(pdf, title: @proposal.title, description_html: @proposal.description)
          render_summary(pdf)
          render_map_image(pdf, @proposal.map_location)
          render_attachment_image(pdf, @proposal.image)
        end
        render_footer(pdf)
      end
    end

    private

      def meta_rows
        rows = []

        if @projekt_phase.present?
          rows << [Proposal.human_attribute_name(:projekt_phase, default: "Projekt"), "#{@projekt_phase.projekt.page.title} — #{@projekt_phase.title}"]
        end

        rows << [Proposal.human_attribute_name(:author, default: "Autor"), @proposal.author.username]
        rows << [Proposal.human_attribute_name(:created_at, default: "Erstellt am"), I18n.l(@proposal.created_at, format: :long)]
        rows << [Proposal.human_attribute_name(:cached_votes_up, default: "Unterstützung"), @proposal.total_votes.to_s]

        if @proposal.admin_accepted?
          rows << [I18n.t("custom.admin.proposals.show.admin_accepted", default: "Akzeptiert"), "Ja"]
        end

        if @proposal.geozone.present?
          rows << [Proposal.human_attribute_name(:geozone, default: "Bezirk"), @proposal.geozone.name]
        end

        rows << ["Link", record_url]

        rows
      end

      def render_summary(pdf)
        summary = @proposal.summary
        return if summary.blank?

        pdf.text Proposal.human_attribute_name(:summary, default: "Zusammenfassung"), size: 11, style: :bold, color: COLORS[:accent]
        pdf.move_down 4
        pdf.text summary, size: 10, color: COLORS[:primary], leading: 4
        pdf.move_down 16
      end

      def record_url
        Rails.application.routes.url_helpers.proposal_url(@proposal, host: @host)
      end
  end
end
