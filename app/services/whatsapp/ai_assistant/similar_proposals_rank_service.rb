class Whatsapp::AiAssistant::SimilarProposalsRankService < ApplicationService
  # Which of the search's candidates are actually the citizen's idea again.
  # The index ranks on word overlap, so on its own it answers "same subject",
  # and in a phase with many proposals its top rows are routinely a different
  # request about the same thing. Asking a citizen "is this yours?" about
  # something that is not trains them to tap straight past the question, which
  # costs more than never asking it.
  #
  # The fast model, like the intent router: a short judgement over a handful of
  # titles on a turn the citizen is already waiting through.
  KEPT_LIMIT = 3
  REQUEST_TIMEOUT_SECONDS = 15
  DESCRIPTION_PREVIEW_LENGTH = 200

  def initialize(idea_text:, proposals:)
    @idea_text = idea_text.to_s.strip
    @proposals = proposals.to_a
  end

  # An empty list is both the common answer and the safe failure: it is the
  # ticket's "none found" branch, where the drafting flow carries on untouched.
  # So an unreachable provider costs the citizen nothing but the check.
  def call
    return [] if @idea_text.blank? || @proposals.blank?
    return [] if !::Ai::Settings.ai_available?

    kept_proposals.first(KEPT_LIMIT)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] similar proposal ranking failed: #{e.class} - #{e.message}")

    []
  end

  private

    # Filtered rather than reordered, so what the citizen sees keeps the
    # portal's own ranking, and an id the model invented matches nothing.
    def kept_proposals
      kept_ids = response_content["proposal_ids"].to_a.map(&:to_i)

      @proposals.select { |proposal| kept_ids.include?(proposal.id) }
    end

    def response_content
      ::Ai::RubyLlmFactory
        .chat_with_request_timeout(
          REQUEST_TIMEOUT_SECONDS,
          gpt_model: ::Ai::Settings::DEFAULT_GPT_FAST_MODEL
        )
        .with_schema(output_schema)
        .with_instructions(instructions)
        .ask(user_prompt)
        .content
        .to_h
    end

    def instructions
      <<~TEXT
        You decide whether a citizen's new idea for a participation project is already covered by
        a proposal that exists.

        Two are the same when they ask for the same concrete thing in the same place. The same
        subject is not enough: "more shade at the playground" and "plant trees at the playground"
        may well be one request, while "renovate the Wiesenweg playground" and "build a second
        playground at Wiesenweg" are two.

        Return the ids of the listed proposals that are the same request as the citizen's idea,
        and an empty list when none of them are. Empty is the ordinary answer: a wrong match sends
        the citizen to support something they did not ask for, which costs more than letting a
        near-duplicate through.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The citizen's idea:
        "#{@idea_text}"

        Existing proposals in the same participation phase:
        #{proposal_lines}
      PROMPT
    end

    def proposal_lines
      @proposals.map { |proposal| proposal_line(proposal) }.join("\n\n")
    end

    def proposal_line(proposal)
      "[id=#{proposal.id}] #{proposal.title}\n#{plain_description(proposal)}"
    end

    # The descriptions are rich text from the portal's editor, and the model is
    # being asked about what they request rather than how they are marked up.
    def plain_description(proposal)
      ActionController::Base.helpers
        .strip_tags(proposal.description.to_s)
        .squish
        .truncate(DESCRIPTION_PREVIEW_LENGTH)
    end

    def output_schema
      {
        type: "object",
        properties: {
          proposal_ids: {
            type: "array",
            items: { type: "integer" },
            description: "Ids of the listed proposals that ask for the same thing as the " \
                         "citizen's idea. Empty when none of them do."
          }
        },
        required: %w[proposal_ids],
        additionalProperties: false
      }
    end
end
