class Evaluations::FormatPdfHtmlJob < ApplicationJob
  queue_as :default

  def perform(evaluation_id)
    evaluation = ProjektEvaluation.find(evaluation_id)

    return if evaluation.pdf_formatting_ready?

    starting_fingerprint = evaluation.current_data_fingerprint

    evaluation.update!(
      pdf_formatted_status: "processing",
      pdf_formatted_error: nil,
      pdf_format_progress: { "stage" => "rendering", "steps" => [] }
    )

    if !Ai::Settings.ai_available?
      evaluation.update!(
        pdf_formatted_status: "failed",
        pdf_formatted_error: "ai_disabled",
        pdf_format_progress: {}
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
    phase_rows_by_id = evaluation.projekt_phase_evaluations.index_by { |r| r.projekt_phase_id.to_s }
    phase_title_by_id = phase_rows_by_id.transform_values { |row| row.data["phase_title"] }
    new_phase_chunks = Hash.new { |h, k| h[k] = {} }

    steps = build_steps(chunks, phase_title_by_id)
    update_progress(evaluation, "formatting", steps)

    chunks_with_ai_html = chunks.each_with_index.map do |chunk, idx|
      mark_step(steps, idx, "processing")
      update_progress(evaluation, "formatting", steps)

      ai_html = resolve_chunk_html(chunk, phase_rows_by_id, new_phase_chunks)

      mark_step(steps, idx, "completed")
      update_progress(evaluation, "formatting", steps)

      chunk.merge(ai_html: ai_html)
    end

    update_progress(evaluation, "stitching", steps)

    stitched = Evaluations::ChunkPdfHtml.stitch(chunks_with_ai_html)

    persist_phase_caches(phase_rows_by_id, new_phase_chunks)

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
      pdf_formatted_error: nil,
      pdf_format_progress: { "stage" => "completed", "steps" => steps }
    )
  rescue StandardError => e
    Rails.logger.error("[Evaluation] FormatPdfHtmlJob failed for ##{evaluation_id}: #{e.message}")
    evaluation&.update(
      pdf_formatted_status: "failed",
      pdf_formatted_error: e.message.to_s.truncate(500),
      pdf_format_progress: { "stage" => "failed" }
    )

    raise
  end

  private

    def build_steps(chunks, phase_title_by_id)
      chunks.map do |chunk|
        {
          "key" => chunk[:key],
          "label" => chunk_label(chunk, phase_title_by_id),
          "phase_id" => chunk[:phase_id].to_s,
          "section" => chunk[:section].to_s,
          "status" => "pending"
        }
      end
    end

    def mark_step(steps, index, status)
      steps[index]["status"] = status
    end

    def update_progress(evaluation, stage, steps)
      evaluation.update_columns(
        pdf_format_progress: {
          "stage" => stage,
          "steps" => steps,
          "total" => steps.size,
          "completed" => steps.count { |s| s["status"] == "completed" }
        }
      )
    end

    def chunk_label(chunk, phase_title_by_id)
      if chunk[:phase_id].blank?
        return I18n.t(
          "adm.projekts.projekts.evaluation.pdf_options.progress.report_chunk_label",
          default: "Report"
        )
      end

      phase_title = phase_title_by_id[chunk[:phase_id].to_s].presence || chunk[:phase_id].to_s
      section_label = I18n.t(
        "adm.projekts.projekts.evaluation.pdf_options.sections.#{chunk[:section]}",
        default: chunk[:section].to_s.humanize
      )

      "#{phase_title} — #{section_label}"
    end

    def resolve_chunk_html(chunk, phase_rows_by_id, new_phase_chunks)
      phase_id = chunk[:phase_id].presence
      row = phase_id ? phase_rows_by_id[phase_id.to_s] : nil

      if row && !row.pdf_formatting_stale?
        cached = row.cached_chunk_html(chunk[:key])
        return cached if cached.present?
      end

      ai_html = format_chunk(chunk)

      if phase_id.present? && row.present? && ai_html != chunk[:html]
        new_phase_chunks[phase_id.to_s][chunk[:key]] = ai_html
      end

      ai_html
    end

    def persist_phase_caches(phase_rows_by_id, new_phase_chunks)
      new_phase_chunks.each do |phase_id, chunks_by_key|
        row = phase_rows_by_id[phase_id.to_s]
        next if row.blank?

        existing = parse_existing_cache(row)
        merged = existing.merge(chunks_by_key)
        row.write_chunk_cache!(merged)
      end
    end

    def parse_existing_cache(row)
      return {} if row.pdf_formatted_html.blank?
      return {} if row.pdf_formatting_stale?

      JSON.parse(row.pdf_formatted_html)
    rescue JSON::ParserError
      {}
    end

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
