class PdfServices::AiFormatHtml < ApplicationService
  DEFAULT_PDF_FORMAT_MODEL = "gpt-5.4-mini"
  TEXT_LOSS_THRESHOLD = 0.10

  def initialize(html, context: {})
    @html = html.to_s
    @context = context
  end

  def call
    return @html if @html.blank?

    response = chat
      .with_instructions(system_instructions)
      .ask(user_prompt)

    formatted_html = response.content.to_s
    cleaned_html = strip_scripts(formatted_html)
    cleaned_html = unwrap_code_fences(cleaned_html)

    enforce_text_loss_guardrail!(cleaned_html)

    cleaned_html
  end

  private

    attr_reader :html, :context

    def chat
      Ai::RubyLlmFactory
        .init
        .chat(
          model: pdf_format_model,
          provider: Ai::Settings.current_llm_provider.to_sym,
          assume_model_exists: true
        )
    end

    def pdf_format_model
      configured = Setting["ai.pdf_format_model"]
      return Ai::Settings.current_llm_model if Ai::Settings.current_llm_provider != "openai"

      configured.presence || DEFAULT_PDF_FORMAT_MODEL
    end

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def system_instructions
      <<~TEXT
        You restructure HTML for clean PDF page splits. The output goes into a print-to-PDF pipeline.

        Hard rules:
        1. Preserve every piece of information from the input HTML. Do not change, rephrase, translate, or remove any text content. Do not add new text content.
        2. The input is a single outermost element with the attributes `data-pdf-chunk`, `data-phase-id`, and `data-section`. Return a single outermost element that carries the SAME attribute values exactly (do not change, drop, or rename them). Keep its original tag name and class list.
        3. Inside that outermost element, wrap each logical group (heading + its supporting content, chart + caption, KPI grid, table with title, key-finding card) inside a `<section class="pdf-block" style="page-break-inside: avoid">`.
        4. Insert `<div style="page-break-before: always"></div>` between logical groups whose combined estimated size would not fit on one A4 page.
        5. Promote isolated short paragraphs into the preceding block to prevent orphan lines.
        6. Strip any `<script>` tags. Do not introduce new scripts.
        7. Return ONLY the restructured outermost element — no `<html>`, `<head>`, `<body>`, no Markdown fences, no extra prose.

        Locale for any inserted micro-labels: #{target_language}.

        Context: #{context.to_json}.
      TEXT
    end

    def user_prompt
      html
    end

    def strip_scripts(input)
      doc = Nokogiri::HTML.fragment(input)
      doc.css("script").each(&:remove)
      doc.to_html
    end

    def unwrap_code_fences(input)
      stripped = input.strip
      return input unless stripped.start_with?("```")

      stripped
        .sub(/\A```(?:html)?\s*/i, "")
        .sub(/```\s*\z/, "")
        .strip
    end

    def enforce_text_loss_guardrail!(output_html)
      input_text_length = text_length(html)
      return if input_text_length.zero?

      output_text_length = text_length(output_html)
      drop_ratio = (input_text_length - output_text_length).to_f / input_text_length

      return if drop_ratio <= TEXT_LOSS_THRESHOLD

      raise "AI output dropped #{(drop_ratio * 100).round(1)}% of text content (threshold #{(TEXT_LOSS_THRESHOLD * 100).round}%)"
    end

    def text_length(input)
      Nokogiri::HTML.fragment(input).text.gsub(/\s+/, " ").strip.length
    end
end
