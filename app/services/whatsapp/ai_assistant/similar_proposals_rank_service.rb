class Whatsapp::AiAssistant::SimilarProposalsRankService < ApplicationService
  # Which of the search's candidates are actually the citizen's idea again.
  # The index ranks on word overlap, so on its own it answers "same subject",
  # and in a phase with many proposals its top rows are routinely a different
  # request about the same thing. Asking a citizen "is this yours?" about
  # something that is not trains them to tap straight past the question, which
  # costs more than never asking it.
  #
  # Each kept proposal comes back with the row line the offer will show for it:
  # the model has just read title and description to judge the match, so the
  # sentence that fits WhatsApp's row budget rides the same completion instead
  # of costing one per row afterwards.
  #
  # The fast model, like the intent router: a short judgement over a handful of
  # titles on a turn the citizen is already waiting through.
  KEPT_LIMIT = 3
  REQUEST_TIMEOUT_SECONDS = 15
  DESCRIPTION_PREVIEW_LENGTH = 200

  # WhatsApp's own budget for a list row's description line.
  ROW_DESCRIPTION_LENGTH = 72

  def initialize(idea_text:, proposals:)
    @idea_text = idea_text.to_s.strip
    @proposals = proposals.to_a
  end

  # An empty result is both the common answer and the safe failure: it is the
  # ticket's "none found" branch, where the drafting flow carries on untouched.
  # So an unreachable provider costs the citizen nothing but the check.
  #
  # `row_descriptions` is keyed by id string, which is what the context the
  # caller stores it in gives back after the jsonb round trip.
  def call
    return none if @idea_text.blank? || @proposals.blank?
    return none if !::Ai::Settings.ai_available?

    kept = kept_entries

    ServiceResult.success(
      proposals: kept.map { |entry| entry[:proposal] },
      row_descriptions: kept.to_h { |entry| [entry[:proposal].id.to_s, entry[:row_description]] }
    )
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] similar proposal ranking failed: #{e.class} - #{e.message}")

    none
  end

  private

    def none
      ServiceResult.success(proposals: [], row_descriptions: {})
    end

    # Filtered rather than reordered, so what the citizen sees keeps the
    # portal's own ranking, and an id the model invented matches nothing. The
    # row line is cut rather than re-asked when it overshoots: the sentence is
    # already whole, and one a few characters long is still better read than a
    # hard cut through the original.
    def kept_entries
      rows_by_id = returned_rows_by_id

      @proposals.filter_map do |proposal|
        row = rows_by_id[proposal.id]

        next if row.blank?

        {
          proposal: proposal,
          row_description: row.to_s.squish.truncate(ROW_DESCRIPTION_LENGTH)
        }
      end.first(KEPT_LIMIT)
    end

    def returned_rows_by_id
      response_content["kept"].to_a.each_with_object({}) do |entry, rows|
        rows[entry["id"].to_i] = entry["row_description"].to_s
      end
    end

    def response_content
      ::Ai::RubyLlmFactory
        .fast_chat(REQUEST_TIMEOUT_SECONDS)
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

        Return the listed proposals that are the same request as the citizen's idea, and an empty
        list when none of them are. Empty is the ordinary answer: a wrong match sends the citizen
        to support something they did not ask for, which costs more than letting a near-duplicate
        through.

        For each proposal you keep, also return row_description: what it asks for and where, in
        at most #{ROW_DESCRIPTION_LENGTH} characters, in the proposal's own language. One whole
        sentence that ends properly, built only from what the proposal says — no judgement,
        nothing added. It is shown to the citizen under the proposal's title, so it must tell
        them what they would be supporting.
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

    # Flattened because the model is being asked what each proposal requests,
    # not how it is marked up — and the markup would be most of the tokens.
    def proposal_line(proposal)
      description = ::Whatsapp.plain_text(proposal.description, length: DESCRIPTION_PREVIEW_LENGTH)

      "[id=#{proposal.id}] #{proposal.title}\n#{description}"
    end

    def output_schema
      {
        type: "object",
        properties: {
          kept: {
            type: "array",
            description: "The listed proposals that ask for the same thing as the citizen's " \
                         "idea. Empty when none of them do.",
            items: {
              type: "object",
              properties: {
                id: {
                  type: "integer",
                  description: "The proposal's id as supplied in the prompt."
                },
                row_description: {
                  type: "string",
                  description: "What the proposal asks for and where, at most " \
                               "#{ROW_DESCRIPTION_LENGTH} characters, one whole sentence, in " \
                               "the proposal's own language."
                }
              },
              required: %w[id row_description],
              additionalProperties: false
            }
          }
        },
        required: %w[kept],
        additionalProperties: false
      }
    end
end
