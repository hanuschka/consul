class PollQuestionImports::PromptBuilder
  MAX_CONTEXT_CHARS = 4_000

  # Held in the app rather than in DT, unlike the projekt import's prompt: this
  # flow has no per-client variation to configure, and a missing DT record would
  # take the whole feature down.
  BASE_PROMPT = <<~PROMPT.strip
    You transcribe poll questions out of a document an administrator uploaded
    for an online participation platform.

    The document contains a list of questions meant for a vote. Each question
    usually stands on its own page or under its own heading, followed by the
    answer options belonging to it.

    Your task is to report the questions the document actually contains. Do not
    invent questions, do not invent answer options, and do not merge two
    questions into one. Leave out headings, introductions, explanatory chapters,
    legal notices and anything else that is not a question to be voted on.

    For every question, report:
    - title: the question itself, as a single sentence.
    - description: any explanatory text the document gives for that question, or
      null when it gives none. Never repeat the title here.
    - vote_type: how the document expects the question to be answered.
      - unique: the voter picks exactly one of the answers. This is the default
        when the document does not say.
      - multiple: the voter may pick several answers, e.g. "multiple answers
        possible".
      - multiple_with_weight: the voter distributes a number of points or votes
        across the answers.
      - rating_scale: the answers form an ordered scale, e.g. school grades or
        "very good" to "very poor". Fill in min_rating_scale_label and
        max_rating_scale_label for these, and leave them null for every other
        vote type.
    - answers: the answer options in the order the document lists them, each
      with its title and, where the document gives one, a description.

    Every question needs at least two answer options. When the document offers
    none for a question, supply the plain options the wording implies (for a
    yes/no question, "Yes" and "No") rather than dropping the question.
  PROMPT

  attr_reader :projekt_phase, :response_language

  def initialize(projekt_phase:, response_language:)
    @projekt_phase = projekt_phase
    @response_language = response_language
  end

  def call
    [
      BASE_PROMPT,
      language_section,
      projekt_section,
      phase_section
    ].compact_blank.join("\n\n")
  end

  private

    def projekt
      projekt_phase.projekt
    end

    # The document is the source of the questions, so the surrounding projekt is
    # context for wording and tone only -- it must not become a second source the
    # model invents questions from.
    def language_section
      <<~SECTION.strip
        Write every question title, question description, answer title and answer
        description in #{response_language}. Do not restate them in any other
        language.
      SECTION
    end

    def projekt_section
      context_section("Projekt this vote belongs to", projekt.name, projekt.description)
    end

    def phase_section
      context_section(
        "Voting phase the questions are created for",
        projekt_phase.title,
        projekt_phase.description
      )
    end

    def context_section(heading, title, description)
      lines = ["#{heading}:", "- Title: #{title}"]
      clean_description = clean_text(description)
      lines << "- Description: #{clean_description}" if clean_description.present?

      lines.join("\n")
    end

    def clean_text(value)
      ActionView::Base.full_sanitizer.sanitize(value.to_s).squish.truncate(MAX_CONTEXT_CHARS)
    end
end
