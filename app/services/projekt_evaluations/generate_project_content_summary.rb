class ProjektEvaluations::GenerateProjectContentSummary < ApplicationService
  CONTENT_TRUNCATE = 6000

  def initialize(projekt)
    @projekt = projekt
  end

  def call
    content = build_content
    return nil if content.blank?

    response_text = get_ai_response(content)
    response_text.to_s.strip.presence
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GenerateProjectContentSummary failed: #{e.message}")
    nil
  end

  private

    attr_reader :projekt

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def build_content
      parts = []
      parts << "Title: #{projekt.page&.title}" if projekt.page&.title.present?
      parts << "Subtitle: #{strip_text(projekt.page&.subtitle)}" if projekt.page&.subtitle.present?

      stripped_content = strip_text(projekt.page_content)
      parts << "Content:\n#{stripped_content.truncate(CONTENT_TRUNCATE)}" if stripped_content.present?

      parts.join("\n\n")
    end

    def strip_text(text)
      return "" if text.blank?

      sanitized = ActionView::Base.full_sanitizer.sanitize(text.to_s)
      sanitized.gsub(/\s+/, " ").strip
    end

    def get_ai_response(content)
      response = Ai::RubyLlmFactory
        .chat
        .with_instructions(system_instructions)
        .ask(content)

      response.content.to_s
    end

    def system_instructions
      <<~TEXT
        You are summarizing the public-facing project page of a citizen participation project.
        Write a neutral and fluent summary in #{target_language}.

        Structure the summary into 2-3 thematic sections. Choose a short, fitting
        heading for each section based on the actual project content (for example
        what the project is about, its goals, and the kind of participation it
        offers). Write each section as a single well-developed paragraph of about
        4-6 sentences, providing enough detail and context to be informative.

        Output valid HTML using only these tags: <h3> for each section heading and
        <p> for each paragraph. Do not use any other tags, no bullet points, no
        lists, no markdown, no inline styles. Output only the HTML — no preamble,
        no code fences, no wrapping element.
      TEXT
    end
end
