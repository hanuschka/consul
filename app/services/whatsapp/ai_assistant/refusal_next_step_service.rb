class Whatsapp::AiAssistant::RefusalNextStepService < ApplicationService
  # One sentence saying what a refused citizen can still do, appended under the
  # refusal itself. The refusal is a permission statement and keeps its exact
  # wording; only what follows it is written here, so a rule is never restated by
  # a model that might restate it differently.
  #
  # The alternatives are not a guess. Each candidate phase is put through
  # ResourceCreationValidationService for this citizen first, so a phase that
  # would refuse them for the same reason — the address restriction they just
  # failed, an age they do not have — never reaches the sentence. Offering one
  # that does is worse than offering none: it sends someone through the whole
  # submission again to be turned away at the end of it.
  REQUEST_TIMEOUT_SECONDS = 15

  # How many phases are checked before giving up, and how many are named. The
  # scan is the expensive half — permission_problem reads the citizen's address
  # and groups per phase — and a sentence naming five projekts is a list, which
  # the help menu already does better.
  MAX_CANDIDATES_SCANNED = 10
  MAX_ALTERNATIVES = 3

  def initialize(reason:, projekt_phase:, user:)
    @reason = reason.to_s
    @projekt_phase = projekt_phase
    @user = user
  end

  # Nil rather than a sentence whenever there is nothing certain to say: no
  # alternatives, AI switched off, a provider that did not answer. The refusal
  # above it is complete on its own, which is what made it safe to add anything
  # under it at all.
  def call
    return if !::Ai::Settings.ai_available?
    return if alternatives.blank?

    next_step
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] refusal next step failed: #{e.class} - #{e.message}")

    nil
  end

  private

    def next_step
      sentence = response_content["next_step"].to_s.squish

      sentence.presence
    end

    # Everything open that this citizen would actually be allowed to submit to,
    # minus the phase they were just refused from. An unlinked citizen is scanned
    # the same way: the validation answers :not_logged_in for every phase that
    # requires an account, so what survives is exactly the guest-participation
    # set.
    def alternatives
      return @alternatives if defined?(@alternatives)

      @alternatives =
        ::Whatsapp::EligiblePhasesQuery
          .uncapped
          .reject { |phase| phase.id == @projekt_phase&.id }
          .first(MAX_CANDIDATES_SCANNED)
          .select { |phase| permitted?(phase) }
          .first(MAX_ALTERNATIVES)
    end

    def permitted?(projekt_phase)
      ::Whatsapp::Drafting::ResourceCreationValidationService.call(
        projekt_phase: projekt_phase, user: @user
      ).blank?
    end

    def alternative_titles
      alternatives.map { |phase| ::Whatsapp::ProjektLink.title(phase.projekt).to_s }
    end

    # The refusal the citizen has just read, in the language they read it in, so
    # the sentence under it does not repeat what it already says.
    def refusal_copy
      ::Whatsapp::Flows::RefuseParticipationService.copy_for(
        reason: @reason, projekt_phase: @projekt_phase
      )
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

    # The tight rein is the point. Everything this sentence may state is in the
    # prompt, and the one failure that matters is inventing a way forward that
    # does not exist — a phone number, an office, a deadline, a projekt not on
    # the list — because a citizen acts on it and finds nothing there.
    def instructions
      <<~TEXT
        A citizen has just been told they cannot contribute to a participation project over
        WhatsApp, and they have read that refusal in full. Write the one sentence that comes after
        it, saying what they can do instead.

        You are given the projects that are open to them. Those have already been checked against
        this citizen's own account, so they may be named as genuinely available.

        Rules:
        - Same language as the refusal you are shown. Never translate.
        - One sentence. Two at the very most, and only when a second is doing real work.
        - Name only the projects in the list, copied character for character. A project name is
          never translated or re-spelled, even when the rest of your sentence is in another
          language — it is what the citizen has to recognise in the portal.
        - State nothing else as fact. No phone numbers, no offices, no addresses, no opening
          hours, no dates, no promises about what happens next, no advice about how to change
          their account.
        - Do not repeat the refusal or explain the rule again. It is directly above your sentence.
        - Do not greet, apologise, or add a closing line.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The refusal the citizen has just read:
        "#{refusal_copy}"

        Projects that are open to them right now:
        #{alternative_titles.map { |title| "- #{title}" }.join("\n")}
      PROMPT
    end

    def output_schema
      {
        type: "object",
        properties: {
          next_step: {
            type: "string",
            description: "One sentence naming what the citizen can do instead, using only the " \
                         "projects listed, in the language of the refusal."
          }
        },
        required: %w[next_step],
        additionalProperties: false
      }
    end
end
