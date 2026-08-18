class Whatsapp::AiAssistant::PhrasingService < ApplicationService
  # The bot's prose, said differently each time. A citizen who submits three
  # ideas in a week used to read the same four sentences nine times, and a chat
  # that repeats itself word for word reads as a form rather than an answer.
  #
  # It is also where the portal's du/Sie setting reaches the fixed copy. The
  # locale files are written formally, so on a portal set to "du" every sentence
  # that goes through here is the informal one — which is why the set below is
  # every prose line the bot sends rather than a shortlist of them: a
  # conversation that mixes the two address forms reads as broken.
  #
  # What stays out of it, deliberately:
  #   * button labels and list-row titles and descriptions — a row title is
  #     matched against what the citizen tapped, and a reworded one matches
  #     nothing;
  #   * pure layout (`proposal.card`, the `*%{title}*` / URL entry lines) — the
  #     citizen's own words in a frame, with no prose to reword;
  #   * one-word status labels, the command menu and the ice breakers, which
  #     WhatsApp itself renders as tappable suggestions;
  #   * `onboarding.consent`, the one line whose exact wording is a legal
  #     declaration rather than copy;
  #   * `notifications.push.*`, which are not sent as prose at all — they are the
  #     bodies of the broadcast templates Meta approves, and an approval says
  #     nothing about text that varies per generation.
  #
  # Interpolated lines belong here too. A lookup with no arguments returns the
  # sentence with its `%{...}` still in it, so GeneratePhrasesService reads the
  # placeholders off the locale file itself and drops any variant that came back
  # without them — nothing about them is restated here, where it could fall out
  # of step with the copy.

  # The lines said on every submission. They get more wordings than the rest
  # because they are the ones a citizen reads repeatedly.
  FREQUENT_KEYS = %w[
    whatsapp.bot.drafting
    whatsapp.bot.proposal.ask_idea
    whatsapp.bot.proposal.ask_revision
    whatsapp.bot.proposal.ask_image
    whatsapp.bot.proposal.draft_intro
    whatsapp.bot.proposal.draft_question
    whatsapp.bot.proposal.draft_revised_intro
    whatsapp.bot.proposal.draft_revised_question
    whatsapp.bot.proposal.preview_intro
    whatsapp.bot.proposal.preview_question
    whatsapp.bot.proposal.cancelled
    whatsapp.bot.proposal.next_action
  ].freeze

  # Everything else the bot says in prose: seen once or twice by any one
  # citizen, but part of the same conversation, so it follows the same address
  # form.
  OCCASIONAL_KEYS = %w[
    whatsapp.bot.welcome_greeting
    whatsapp.bot.free_text_hint
    whatsapp.bot.no_open_phase_notice
    whatsapp.bot.no_projekt
    whatsapp.bot.idea_missing
    whatsapp.bot.proposal.continue_or_restart
    whatsapp.bot.draft_failed
    whatsapp.bot.transcription_failed
    whatsapp.bot.publish_failed
    whatsapp.bot.draft_invalid
    whatsapp.bot.criteria_failed
    whatsapp.bot.safety_check_failed
    whatsapp.bot.too_fast
    whatsapp.bot.opted_in
    whatsapp.bot.verification_link
    whatsapp.bot.contributions.intro
    whatsapp.bot.contributions.more
    whatsapp.bot.contributions.empty
    whatsapp.bot.projekt_contributions.intro
    whatsapp.bot.projekt_contributions.more
    whatsapp.bot.projekt_contributions.empty
    whatsapp.bot.main_menu.onboarding_body
    whatsapp.bot.main_menu.start_over_body
    whatsapp.bot.participation.choose_projekt
    whatsapp.bot.participation.actions_body
    whatsapp.bot.participation.closed
    whatsapp.bot.participation.prompts.support
    whatsapp.bot.participation.prompts.comment
    whatsapp.bot.link_request.contributions
    whatsapp.bot.link_request.notifications
    whatsapp.bot.link_request.participation
    whatsapp.bot.link_request.support
    whatsapp.bot.link_request.comment
    whatsapp.bot.refused_content.intro
    whatsapp.bot.refused_content.retry_hint
    whatsapp.bot.refused_content.reasons.generic
    whatsapp.bot.refused_content.reasons.hate
    whatsapp.bot.refused_content.reasons.violence
    whatsapp.bot.refused_content.reasons.harassment
    whatsapp.bot.refused_content.reasons.sexual
    whatsapp.bot.refused_content.reasons.illegal
    whatsapp.bot.refused_content.reasons.personal_data
    whatsapp.bot.refused_content.reasons.spam
    whatsapp.bot.refused.generic
    whatsapp.bot.refused.phase_missing
    whatsapp.bot.refused.phase_not_supported
    whatsapp.bot.refused.budget_heading_missing
    whatsapp.bot.refused.creation_disabled
    whatsapp.bot.refused.ai_flow_disabled
    whatsapp.bot.refused.phase_not_active
    whatsapp.bot.refused.phase_expired
    whatsapp.bot.refused.phase_not_current
    whatsapp.bot.refused.not_verified
    whatsapp.bot.refused.submissions_limit_exceeded
    whatsapp.bot.refused.no_open_phase
    whatsapp.bot.refused.not_logged_in
    whatsapp.bot.refused.organization
    whatsapp.bot.refused.missing_user_data
    whatsapp.bot.refused.only_citizens
    whatsapp.bot.refused.only_specific_geozones
    whatsapp.bot.refused.no_registered_address
    whatsapp.bot.refused.only_specific_streets
    whatsapp.bot.refused.only_specific_registered_address_groupings
    whatsapp.bot.refused.only_specific_ages
    whatsapp.bot.refused.only_specific_individual_group_values
    whatsapp.bot.onboarding.disclosure
    whatsapp.bot.onboarding.login_prompt
    whatsapp.bot.onboarding.login_prompt_with_url
    whatsapp.bot.onboarding.linked
    whatsapp.bot.onboarding.discovery_offer
    whatsapp.bot.onboarding.declined
    whatsapp.bot.onboarding.no_account
    whatsapp.bot.onboarding.expired
    whatsapp.bot.onboarding.already_linked
    whatsapp.bot.onboarding.number_taken
    whatsapp.bot.onboarding.unlink_confirm
    whatsapp.bot.onboarding.unlinked
    whatsapp.bot.discovery.body
    whatsapp.bot.discovery.guest_body
    whatsapp.bot.discovery.phase_body
    whatsapp.bot.discovery.empty
    whatsapp.bot.discovery.public_intro
    whatsapp.bot.discovery.more
    whatsapp.bot.notifications.settings_title
    whatsapp.bot.notifications.saved
    whatsapp.bot.proposal.ask_category
    whatsapp.bot.proposal.ask_sentiment
    whatsapp.bot.proposal.category_line
    whatsapp.bot.proposal.sentiment_line
    whatsapp.bot.proposal.evaluation_line
    whatsapp.bot.proposal.published
    whatsapp.bot.proposal.published_pending_moderation
    whatsapp.bot.proposal.unclear
    whatsapp.bot.proposal.resume
    whatsapp.bot.proposal.resume_projekt
    whatsapp.bot.proposal.resume_draft
    whatsapp.bot.proposal.resume_recap_idea
    whatsapp.bot.proposal.image_upload_prompt
    whatsapp.bot.proposal.image_received
    whatsapp.bot.proposal.image_failed
    whatsapp.bot.proposal.image_generating
    whatsapp.bot.proposal.image_generate_failed
    whatsapp.bot.proposal.ask_location
    whatsapp.bot.proposal.location_request
    whatsapp.bot.proposal.location_retry
    whatsapp.bot.proposal.location_received
    whatsapp.bot.proposal.location_failed
    whatsapp.bot.proposal.duplicate.single
    whatsapp.bot.proposal.duplicate.single_without_url
    whatsapp.bot.proposal.duplicate.multiple
    whatsapp.bot.proposal.link.body
    whatsapp.bot.support.prompt
    whatsapp.bot.support.prompt_without_url
    whatsapp.bot.support.thanks
    whatsapp.bot.support.thanks_without_url
    whatsapp.bot.support.already
    whatsapp.bot.support.gone
    whatsapp.bot.support.refused_intro
    whatsapp.bot.comment.prompt
    whatsapp.bot.comment.confirmation_only
    whatsapp.bot.comment.published
    whatsapp.bot.comment.pending
    whatsapp.bot.comment.invalid
    whatsapp.bot.comment.closed
    whatsapp.bot.declined.offer
    whatsapp.bot.declined.unlink
    whatsapp.bot.subscription.followed
    whatsapp.bot.subscription.unfollowed
    whatsapp.bot.subscription.unknown
    whatsapp.bot.compliance.disclosure
    whatsapp.bot.compliance.out_of_scope
    whatsapp.bot.compliance.opted_out
  ].freeze

  # One map, so a caller only has to ask whether a key is phrased at all. The
  # split above is about how much variety each half is worth, not about which
  # lines follow the setting — all of them do.
  PHRASED_KEYS = (FREQUENT_KEYS + OCCASIONAL_KEYS).freeze

  # Enough that a run of messages does not repeat, few enough that one call
  # produces them all. They are generated together on purpose: asked one at a
  # time the model writes the same sentence twice.
  FREQUENT_VARIANT_COUNT = 5

  # Two is what the long tail is worth: a line a citizen sees once does not need
  # five wordings, and the whole set is one generation the portal pays for.
  OCCASIONAL_VARIANT_COUNT = 2

  # Small enough that no single completion is asked for a hundred rewrites at
  # once, which is where a model starts dropping entries and repeating itself.
  OCCASIONAL_CHUNK_SIZE = 25

  # Long, because the alternative is paying for a completion on a message that
  # is otherwise instant. A portal that changes its address form waits this out
  # or restarts, which is the same deal every Setting-backed cache here makes.
  CACHE_TTL = 12.hours

  # How long a miss stands before another one is scheduled. It doubles as the
  # negative cache: a provider that is down leaves the empty set in place for
  # this long instead of being asked again by every message.
  PENDING_TTL = 5.minutes

  # What a set stands for when a chunk failed. Longer than PENDING_TTL, which is
  # sized for "a generation is already in flight": a retry regenerates all six
  # chunks, so retrying a persistently failing one every five minutes re-pays the
  # five that succeeded ~288 times a day to get the sixth. Short enough that a
  # provider that recovers is picked up the same hour.
  PARTIAL_TTL = 30.minutes

  def initialize(key:, **interpolations)
    @key = key.to_s
    @interpolations = interpolations
  end

  # Always returns something sendable, and never waits on a completion to do
  # it. A miss schedules the generation and answers from the locale file this
  # time; the variety appears on the next message rather than costing this
  # citizen the round trip.
  #
  # Every other failure — AI switched off, the key not on the list, an
  # unreachable provider, a reply that came back empty — lands on the same
  # fallback, which is the sentence the variants were generated from.
  # The lines that are not messages of their own: fragments joined into one body
  # by the caller, a recap line under a question, a reason under an intro. A
  # live rewrite reads them without their neighbours and answers the citizen
  # twice or contradicts the line above, so they keep the pre-generated wording
  # — which was generated the same way, but as a set that fits together.
  #
  # `compliance.disclosure` is here for a different reason: it is the sentence
  # that tells the citizen they are talking to an AI, and what that says must
  # not itself be improvised.
  LITERAL_KEYS = %w[
    whatsapp.bot.free_text_hint
    whatsapp.bot.compliance.disclosure
    whatsapp.bot.proposal.category_line
    whatsapp.bot.proposal.sentiment_line
    whatsapp.bot.proposal.evaluation_line
    whatsapp.bot.proposal.resume_projekt
    whatsapp.bot.proposal.resume_draft
    whatsapp.bot.proposal.resume_recap_idea
    whatsapp.bot.contributions.intro
    whatsapp.bot.contributions.more
    whatsapp.bot.projekt_contributions.intro
    whatsapp.bot.projekt_contributions.more
    whatsapp.bot.discovery.more
    whatsapp.bot.discovery.public_intro
    whatsapp.bot.refused_content.retry_hint
  ].freeze

  # Three answers, in falling order of how much this conversation shaped them:
  # a line written for the message being answered right now, one of the wordings
  # generated for this portal's address form, or the locale file. Each step down
  # is a fallback, so nothing here can leave the bot without something to send.
  def call
    return fixed_text if !prose?

    live_text = live_rewrite

    return live_text if live_text.present?
    return fixed_text if !phrasable?

    variant = variants.sample

    return fixed_text if variant.blank?

    interpolated(variant)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] phrasing failed for #{@key}: #{e.class} - #{e.message}")

    fixed_text
  end

  # Part of the cache key, so changing which lines are phrased invalidates the
  # stored sets by itself. An entry written before the change holds the old keys
  # for up to CACHE_TTL, and every key that was added would answer from the
  # formal locale file until it expired — half a deploy's worth of bot in the
  # wrong register, with nothing to say why. Derived rather than a number to
  # bump, because a number to bump is a number to forget.
  KEY_SET_DIGEST = Digest::MD5.hexdigest(PHRASED_KEYS.join)[0, 8].freeze

  # The cache key is the whole identity of a phrase set: one entry per locale
  # and address form, holding every key at once. Exposed so the job that fills
  # it writes to exactly the entry the request looked in.
  def self.cache_key(locale:, address_form:)
    ["whatsapp/phrasing", KEY_SET_DIGEST, locale, address_form].join("/")
  end

  # Called from the job, off the inbound path. Returns the set it stored.
  #
  # The address form is read fresh rather than taken from the caller: it is
  # what the prompt is built from, so writing this generation under the form
  # that was current when the job was enqueued would file a "du" set under
  # "sie". An admin who flips the setting mid-flight leaves the old entry to
  # expire on its own and the next miss schedules the new one.
  def self.refresh(locale:)
    I18n.with_locale(locale) do
      generation = generate_phrase_set
      phrases = generation[:phrases]
      key = cache_key(locale: locale, address_form: ::Whatsapp.address_form)

      Rails.cache.write(key, phrases, expires_in: generation[:complete] ? CACHE_TTL : PARTIAL_TTL)

      log_generation(key, phrases)

      phrases
    end
  end

  # The merged set, and whether every chunk came back — two answers because they
  # decide different things: what to store, and how long to trust it.
  #
  # Written once, after every chunk, rather than chunk by chunk: nothing in a
  # stored set distinguishes "half generated" from "these are all the phrased
  # keys there are", so a partial write is read as complete.
  def self.generate_phrase_set
    return { phrases: {}, complete: false } if !::Ai::Settings.ai_available?

    chunk_results = generation_chunks.map { |chunk| generate_chunk(**chunk) }

    {
      phrases: chunk_results.compact.reduce({}, :merge),
      complete: chunk_results.none?(&:nil?)
    }
  end

  # A chunk that fails takes its own keys down and nothing else, and says so with
  # nil: six completions fill this set, and letting one unreachable provider
  # discard the five that came back would put the whole bot on the formal locale
  # file over a failure that touched a fifth of it.
  #
  # Keys the model answered badly for are a different thing, and deliberately do
  # not count as failure — a set missing one line whose variants were all dropped
  # is still worth the full TTL. Treating that as incomplete would put the whole
  # generation on a five-minute retry loop that never converges, because the next
  # attempt drops the same line.
  def self.generate_chunk(keys:, variant_count:)
    Whatsapp::AiAssistant::GeneratePhrasesService.call(keys: keys, variant_count: variant_count)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] phrasing chunk failed: #{e.class} - #{e.message}")

    nil
  end

  # The whole set is one cache value, and a store that refuses an oversized one
  # fails the write silently — every message would fall back to the locale file
  # with nothing to say why. The dropped keys are named rather than counted: a
  # line that never survives generation is a line to fix in the copy, and a bare
  # count gives nobody the means to find it. Block form because production logs
  # at warn and the size is what costs.
  def self.log_generation(key, phrases)
    Rails.logger.info do
      "[Whatsapp] phrasing #{key}: #{phrases.size} keys, " \
        "#{Marshal.dump(phrases).bytesize} bytes, dropped: #{(PHRASED_KEYS - phrases.keys).inspect}"
    end
  end

  private_class_method :generate_chunk, :log_generation

  # The frequent lines in one call at five wordings each, the tail in slices at
  # two. Separate completions rather than one: the whole set in a single prompt
  # is where a model starts answering for half the keys it was given.
  def self.generation_chunks
    tail_chunks = OCCASIONAL_KEYS.each_slice(OCCASIONAL_CHUNK_SIZE).map do |keys|
      { keys: keys, variant_count: OCCASIONAL_VARIANT_COUNT }
    end

    [{ keys: FREQUENT_KEYS, variant_count: FREQUENT_VARIANT_COUNT }] + tail_chunks
  end

  private

    def fixed_text
      I18n.t(@key, **@interpolations)
    end

    # The line written for this exact message, or nil — which is every case the
    # rewriter will not vouch for, and every case outside the inbound path,
    # where there is no citizen mid-sentence to write for.
    #
    # The fixed sentence is what gets rewritten, not a generated variant: the
    # variants exist to keep repeated copy from reading as a form, and a
    # paraphrase of a paraphrase drifts further from the meaning the locale file
    # is the record of.
    def live_rewrite
      return if LITERAL_KEYS.include?(@key)

      context = Current.whatsapp_message_context

      return if context.blank?

      Whatsapp::AiAssistant::WriteMessageService.call(
        fixed_text: fixed_text, context: context
      )
    end

    # A variant carries the same placeholders its original did — the generation
    # drops any that does not — so it is rendered with the arguments the caller
    # passed exactly as `I18n.t` would have.
    def interpolated(variant)
      I18n.interpolate(variant, @interpolations)
    end

    # Whether this key is one of the bot's sentences at all, as opposed to a
    # button label, a layout line or the consent declaration. It gates both the
    # live rewrite and the stored variants, because what may be reworded is a
    # property of the line rather than of who is doing the rewording.
    def prose?
      PHRASED_KEYS.include?(@key)
    end

    # The stored-variant path only. Deliberately without the availability
    # check: that one reads a credential out of the database, and the request
    # path never generates anything, so the question belongs in the job. Both
    # checks here are free.
    def phrasable?
      prose? && cacheable?
    end

    # Without a cache this is a completion on every message the bot sends,
    # including the ones that are instant today. Development runs on the null
    # store unless caching is switched on, and paying for variety nobody asked
    # for is the wrong default there — the fixed sentence is.
    def cacheable?
      !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
    end

    # One entry for the whole set rather than one per line. A message that
    # produces a draft says three of these — the "one moment", the sentence
    # above the card and the question under it — and one entry means one
    # generation covers all three rather than three of them expiring at three
    # different times.
    #
    # The address form is part of the key rather than a reason to expire it: a
    # portal that switches from Sie to du would otherwise keep answering in the
    # old one until the TTL ran out.
    def cache_key
      self.class.cache_key(locale: I18n.locale, address_form: ::Whatsapp.address_form)
    end

    def variants
      phrase_set[@key].to_a
    end

    # Read once per message, not once per sentence. One entry now holds every
    # phrased line, and a reply that produces a draft asks for six of them —
    # six reads of the same 25 KB value, deserialized six times, for six short
    # sentences. Memoized the way Setting does it, on Current, because the
    # executor resets that around each job and the inbound path is a job rather
    # than a request: nothing else in the process would clear it.
    def phrase_set
      sets = (Current.whatsapp_phrase_sets ||= {})

      return sets[cache_key] if sets.key?(cache_key)

      sets[cache_key] = read_phrase_set
    end

    # `nil` means nothing is stored, which schedules a refresh and answers from
    # the locale file meanwhile. An empty hash means a refresh is already
    # scheduled, or its generation failed; it stands for PENDING_TTL so the
    # next message neither waits nor enqueues the same job again.
    def read_phrase_set
      cached = Rails.cache.read(cache_key)

      return cached if !cached.nil?

      schedule_refresh

      {}
    end

    # The empty set is written here rather than by the job, and before the job
    # is enqueued: that write is the whole reason a burst of messages produces
    # one generation instead of one each.
    def schedule_refresh
      Rails.cache.write(cache_key, {}, expires_in: PENDING_TTL)

      Whatsapp::RefreshPhrasingJob.perform_later(I18n.locale.to_s)
    end
end
