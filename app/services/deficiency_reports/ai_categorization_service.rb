require "timeout"

module DeficiencyReports
  # Picks a category and, where the taxonomy offers one, a subcategory for a report the citizen
  # never categorized themselves. Always returns a Result and never raises: a report that cannot be
  # classified still has to reach the administration. Every unhappy path — feature off, provider
  # down, timeout, unusable answer — comes back as a Result carrying the fallback category and a
  # fallback_reason, so the caller assigns the same way regardless.
  class AiCategorizationService < ApplicationService
    DT_PROMPT_KEY = :deficiency_report_categorize
    MINIMUM_CONFIDENCE = 0.6
    TIMEOUT_SECONDS = 10
    MAX_AI_HINT_LENGTH = 300

    Result = Struct.new(:category, :subcategory, :confidence, :fallback_reason, keyword_init: true) do
      def fallback?
        fallback_reason.present?
      end
    end

    def initialize(deficiency_report)
      @deficiency_report = deficiency_report
    end

    def call
      return fallback(:disabled) unless self.class.enabled?
      return fallback(:no_categories) if categories.none?

      classify
    rescue StandardError => e
      # An unreachable provider, a timeout, a schema the model ignored: all of them mean the same
      # thing here, and none of them may cost the citizen their submission.
      Rails.logger.error("[AiCategorization] #{e.class}: #{e.message}")
      Sentry.capture_exception(e, level: :warning) if defined?(Sentry)
      fallback(:service_error)
    end

    def self.enabled?
      Setting["deficiency_reports.ai_categorization"].present? && Ai::Settings.ai_available?
    end

    private

      attr_reader :deficiency_report

      def classify
        response = Timeout.timeout(TIMEOUT_SECONDS) do
          chat.ask(user_prompt, with: image_attachment)
        end

        build_result(response.content)
      end

      def chat
        Ai::RubyLlmFactory
          .chat_with_json_output(output_schema, feature: "deficiency_reports.categorization")
          .with_instructions(system_instructions)
      end

      def build_result(content)
        content = content.with_indifferent_access if content.respond_to?(:with_indifferent_access)
        confidence = content[:confidence].to_f

        return fallback(:low_confidence, confidence: confidence) if confidence < MINIMUM_CONFIDENCE

        category = categories.find { |c| c.id == content[:category_id].to_i }
        return fallback(:unknown_category, confidence: confidence) if category.nil?

        # The model is told to send null when the category has no subcategories, but it is also free
        # to get that wrong, so the pair is checked here rather than trusted.
        subcategory = category.subcategories.find { |s| s.id == content[:subcategory_id].to_i }

        Result.new(category: category, subcategory: subcategory, confidence: confidence)
      end

      def fallback(reason, confidence: nil)
        Result.new(category: DeficiencyReport::Category.ai_fallback, subcategory: nil,
                   confidence: confidence, fallback_reason: reason)
      end

      # Only images are worth sending: a PDF or a video link tells a vision model nothing about a
      # pothole, and the attachment has to be readable before the report itself is saved, which is
      # why the blob is resolved rather than the association.
      def image_attachment
        blob = deficiency_report.image&.attachment
        return nil unless blob.respond_to?(:attached?) && blob.attached?
        return nil unless blob.blob.content_type.to_s.start_with?("image/")

        blob
      rescue StandardError => e
        Rails.logger.warn("[AiCategorization] image unavailable, continuing text-only: #{e.message}")
        nil
      end

      def categories
        @categories ||= DeficiencyReport::Category.includes(:subcategories).to_a
      end

      def taxonomy
        categories.map do |category|
          subcategories = category.subcategories.map do |subcategory|
            "    - #{subcategory.id}: #{subcategory.name}#{ai_hint(subcategory)}"
          end.join("\n")

          entry = "- #{category.id}: #{category.name}#{ai_hint(category)}"
          subcategories.present? ? "#{entry}\n#{subcategories}" : "#{entry}\n    (keine Unterkategorien)"
        end.join("\n")
      end

      # A category name like "Sonstiges" or "Ordnung" says nothing about what a given municipality
      # files under it, and the system prompt is maintained centrally, so it cannot say either. The
      # hints are the one place that knowledge fits. Blank ones emit nothing: a client who never
      # fills them in gets exactly the list this built before.
      def ai_hint(record)
        hint = record.ai_hint.to_s.squish
        return "" if hint.blank?

        " — #{hint.truncate(MAX_AI_HINT_LENGTH)}"
      end

      def ai_hints?
        return @ai_hints if defined?(@ai_hints)

        @ai_hints = categories.any? do |category|
          category.ai_hint.present? || category.subcategories.any? { |s| s.ai_hint.present? }
        end
      end

      # The hints have to explain themselves next to the list rather than in the system prompt: a
      # client running the centrally maintained prompt would otherwise get a prompt that predates
      # this field and treats the hints as decoration.
      def ai_hint_legend
        return "" unless ai_hints?

        "\n\nDie Angabe hinter „—“ ist ein verbindlicher Abgrenzungshinweis der Verwaltung. Er legt " \
          "fest, was zu einer Kategorie oder Unterkategorie gehört und was nicht, und hat Vorrang " \
          "vor dem, was der Name allein nahelegt."
      end

      def user_prompt
        <<~PROMPT
          Titel: #{deficiency_report.title}
          Beschreibung: #{ActionController::Base.helpers.strip_tags(deficiency_report.description).to_s.truncate(2000)}

          Verfügbare Kategorien (id: Name) mit ihren Unterkategorien:
          #{taxonomy}#{ai_hint_legend}
        PROMPT
      end

      def system_instructions
        remote_system_prompt.presence || DEFAULT_SYSTEM_PROMPT
      end

      # Prompts for this platform are maintained centrally, but a client whose DT API is unreachable
      # — or who has not had the prompt created yet — still gets a working classifier.
      def remote_system_prompt
        DtApi::Client.new(use_cache: true)
          .consul_ai_prompts
          .get(DT_PROMPT_KEY)
          .parsed_response
          &.dig("consul_ai_prompt", "prompt")
      rescue StandardError => e
        Rails.logger.info("[AiCategorization] falling back to built-in prompt: #{e.message}")
        nil
      end

      DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
        Du kategorisierst Anliegen, die Bürgerinnen und Bürger einer deutschen Kommune melden
        (z. B. Schlaglöcher, defekte Straßenlaternen, wilder Müll).

        Wähle genau eine Kategorie aus der übergebenen Liste und, falls die gewählte Kategorie
        Unterkategorien hat, genau eine passende Unterkategorie. Hat die Kategorie keine
        Unterkategorien, gib für subcategory_id null zurück. Verwende ausschließlich IDs aus der
        Liste; erfinde keine IDs.

        Berücksichtige Titel, Beschreibung und – falls ein Foto beiliegt – dessen Bildinhalt.

        Steht hinter einer Kategorie oder Unterkategorie ein Abgrenzungshinweis der Verwaltung,
        richte dich danach: Er hat Vorrang vor dem, was der Name allein nahelegt.

        Gib in confidence einen Wert zwischen 0 und 1 an, der ausdrückt, wie sicher die Zuordnung
        ist. Nutze niedrige Werte, wenn die Meldung mehrdeutig ist, zu wenig Information enthält
        oder zu keiner der Kategorien wirklich passt. Rate nicht: eine niedrige Confidence ist
        besser als eine falsche Kategorie.
      PROMPT

      def output_schema
        {
          type: "object",
          properties: {
            category_id: {
              type: "integer",
              description: "The id of the best matching main category, taken from the provided list."
            },
            subcategory_id: {
              type: %w[integer null],
              description: "The id of the best matching subcategory of the chosen category, " \
                           "or null when that category has no subcategories or none of them fit."
            },
            confidence: {
              type: "number",
              description: "How certain the classification is, between 0 and 1."
            }
          },
          required: ["category_id", "subcategory_id", "confidence"],
          additionalProperties: false
        }
      end
  end
end
