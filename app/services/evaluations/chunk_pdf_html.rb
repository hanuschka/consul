class Evaluations::ChunkPdfHtml < ApplicationService
  MAX_CHUNK_CHARS = 30_000

  def initialize(html)
    @html = html.to_s
  end

  def call
    return [] if @html.blank?

    doc = Nokogiri::HTML(@html)
    chunk_nodes = doc.css("[data-pdf-chunk]")
    top_level_nodes = chunk_nodes.reject do |node|
      node.ancestors("[data-pdf-chunk]").any?
    end

    top_level_nodes.map do |node|
      {
        key: node["data-pdf-chunk"],
        phase_id: node["data-phase-id"],
        section: node["data-section"],
        html: node.to_html,
        oversized: node.to_html.length > MAX_CHUNK_CHARS
      }
    end
  end

  def self.stitch(chunks_with_ai_html)
    chunks_with_ai_html.map { |chunk| chunk[:ai_html].presence || chunk[:html] }.join("\n")
  end
end
