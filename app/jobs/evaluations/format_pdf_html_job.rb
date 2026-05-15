class Evaluations::FormatPdfHtmlJob < ApplicationJob
  queue_as :default

  def perform(evaluation_id)
    evaluation = ProjektEvaluation.find(evaluation_id)

    if evaluation.pdf_formatted_html.present? && !evaluation.pdf_formatting_stale?
      return
    end

    starting_fingerprint = evaluation.current_data_fingerprint

    evaluation.update!(
      pdf_formatted_status: "processing",
      pdf_formatted_error: nil
    )

    if !Ai::Settings.ai_available?
      evaluation.update!(
        pdf_formatted_status: "failed",
        pdf_formatted_error: "ai_disabled"
      )
      return
    end

    projekt = evaluation.projekt
    selection = PdfServices::EvaluationPdfSelection.all(evaluation)

    html = ApplicationController.renderer.render(
      template: "adm/projekts/projekts/evaluation/pdf",
      layout: "pdf_evaluation",
      locals: {
        projekt: projekt,
        evaluation: evaluation,
        selection: selection
      }
    )

    chunks = Evaluations::ChunkPdfHtml.call(html)
    chunks_with_ai_html = chunks.map do |chunk|
      ai_html = format_chunk(chunk)
      chunk.merge(ai_html: ai_html)
    end

    stitched = Evaluations::ChunkPdfHtml.stitch(chunks_with_ai_html)

    evaluation.reload
    if evaluation.current_data_fingerprint != starting_fingerprint
      Rails.logger.warn(
        "[Evaluation] FormatPdfHtmlJob discarding result for ##{evaluation.id}: " \
        "data fingerprint changed during run"
      )
      return
    end

    evaluation.update!(
      pdf_formatted_html: stitched,
      pdf_formatted_status: "completed",
      pdf_formatted_at: Time.current,
      pdf_formatted_data_fingerprint: starting_fingerprint,
      pdf_formatted_error: nil
    )
  rescue StandardError => e
    Rails.logger.error("[Evaluation] FormatPdfHtmlJob failed for ##{evaluation_id}: #{e.message}")
    evaluation&.update(
      pdf_formatted_status: "failed",
      pdf_formatted_error: e.message.to_s.truncate(500)
    )

    raise
  end

  private

    def format_chunk(chunk)
      Rails.logger.info(
        "[Evaluation] FormatPdfHtmlJob processing chunk key=#{chunk[:key]} " \
        "phase_id=#{chunk[:phase_id]} section=#{chunk[:section]} " \
        "chars_in=#{chunk[:html].to_s.length} oversized=#{chunk[:oversized]}"
      )

      if chunk[:oversized]
        Rails.logger.warn(
          "[Evaluation] FormatPdfHtmlJob skipping AI for oversized chunk key=#{chunk[:key]}"
        )
        return chunk[:html]
      end

      result = PdfServices::AiFormatHtml.call(
        chunk[:html],
        context: {
          key: chunk[:key],
          phase_id: chunk[:phase_id],
          section: chunk[:section]
        }
      )

      if !preserves_chunk_attributes?(result, chunk)
        Rails.logger.warn(
          "[Evaluation] FormatPdfHtmlJob fallback to raw chunk key=#{chunk[:key]} " \
          "(AI output dropped chunk attributes)"
        )
        return chunk[:html]
      end

      Rails.logger.info(
        "[Evaluation] FormatPdfHtmlJob chunk key=#{chunk[:key]} chars_out=#{result.to_s.length}"
      )

      result
    rescue StandardError => e
      Rails.logger.warn(
        "[Evaluation] FormatPdfHtmlJob chunk key=#{chunk[:key]} failed: #{e.message} " \
        "— falling back to original chunk HTML"
      )
      chunk[:html]
    end

    def preserves_chunk_attributes?(ai_html, chunk)
      return false if ai_html.to_s.strip.empty?

      fragment = Nokogiri::HTML.fragment(ai_html)
      first_element = fragment.children.find(&:element?)
      return false if first_element.nil?

      first_element["data-pdf-chunk"].to_s == chunk[:key].to_s &&
        first_element["data-phase-id"].to_s == chunk[:phase_id].to_s &&
        first_element["data-section"].to_s == chunk[:section].to_s
    end
end
