class PdfServices::FilterFormattedHtml < ApplicationService
  def initialize(html, selection)
    @html = html.to_s
    @selection = selection
  end

  def call
    return @html if @html.blank?

    doc = Nokogiri::HTML.fragment(@html)

    if !@selection.include_report?
      doc.css('[data-pdf-chunk="report"]').each(&:remove)
    end

    doc.css('[data-pdf-chunk^="phase:"]').each do |node|
      phase_id = node["data-phase-id"]
      section = node["data-section"]

      if !@selection.include_section?(phase_id, section)
        node.remove
      end
    end

    doc.to_html
  end
end
