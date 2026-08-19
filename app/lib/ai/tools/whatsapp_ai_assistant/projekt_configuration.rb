class Ai::Tools::WhatsappAiAssistant::ProjektConfiguration <
  Ai::Tools::WhatsappAiAssistant::BaseTool

  # What is *set up* for a projekt, as opposed to what is written on it. Before
  # this the assistant could read a projekt's content and one verdict about the
  # citizen's own eligibility, and nothing else: asked how many proposals it
  # takes, who may join in, or whether a contribution is checked before it goes
  # online, it had no tool to call and either refused or guessed.
  #
  # Every setting the phase carries, not a shortlist of them. The filter below is
  # a blocklist on purpose — a setting added to a phase type next year is
  # answerable the day it exists, and only the ones that are about running the
  # portal rather than taking part in it have to be named to be kept back.
  HIDDEN_SETTING_KEYS = %w[
    feature.form.voice_assistant
    feature.form.enable_geoman_controls_in_maps
    feature.form.use_masterportal_collections_as_labels
    feature.form.show_implementation_option_fields
    feature.general.newest_first
    feature.general.reverse_order_for_incoming_events
    feature.general.show_questions_list
    feature.resource.create_proposal_with_ai
    feature.resource.create_investment_with_ai
    feature.resource.evaluation_enabled
    feature.resource.stats_enabled
    feature.resource.results_enabled
    feature.resource.intermediate_poll_results_for_admins
    feature.resource.show_related_content
    feature.resource.show_social_share_buttons
    feature.resource.show_video_as_link
    feature.resource.wizard_mode
    selectable_setting.general.default_order
  ].freeze

  # The same judgement by shape, for the families that keep growing: where a
  # phase appears in the portal, which buttons and tabs its sidebar carries, and
  # the plumbing of an embedded page. None of it is a rule about taking part.
  HIDDEN_SETTING_PATTERNS = [
    /\Afeature\.\w+\.show_on_/,
    /_sidebar\z/,
    /\Afeature\.resource\.enable_proposal_\w+_tab\z/,
    /browse_mode_in_phase_footer/,
    /\Aoption\.general\.iframe_/,
    /\Aoption\.general\.newsfeed_/
  ].freeze

  # Projekt-level rows are almost entirely about where the projekt is listed and
  # what its sidebar shows, so the same blocklist reading applies one level up.
  HIDDEN_PROJEKT_SETTING_PATTERNS = [
    /\Aprojekt_feature\.main\./,
    /\Aprojekt_feature\.general\.show_in_/,
    /\Aprojekt_feature\.general\.allow_indexing\z/,
    /\Aprojekt_feature\.general\.show_related_projekt_link\z/,
    /\Aprojekt_feature\.sidebar\./,
    /\Aprojekt_custom_feature\./
  ].freeze

  # The restriction readers below each walk their own association, so five of
  # them over ten phases is fifty queries the phase query does not make: it
  # preloads what every caller needs, and this is the only caller that asks who
  # may take part.
  RESTRICTION_ASSOCIATIONS = [
    :age_restriction,
    :geozone_restrictions,
    :registered_address_districts,
    :registered_address_streets,
    :individual_group_values
  ].freeze

  ON = "yes".freeze
  OFF = "no".freeze
  UNSET = "not set".freeze

  description "Reads everything that is *set up* for one project and its phases — who may take " \
              "part and under which restrictions, whether an account or a verified account is " \
              "needed, how many contributions one person may submit and how many they may " \
              "support, when each phase starts and ends, whether a contribution is reviewed " \
              "before it goes online, whether a photo or a document may be attached, and every " \
              "other setting the phases carry. Call this for any question about the rules or " \
              "conditions of a project rather than about its content. Whether a phase takes " \
              "contributions at all is one of its settings; submission_through_this_chat only " \
              "says whether this chat can carry one there. What it does not return is " \
              "not set for that project: say so instead of filling the gap. Returns facts for " \
              "you to answer in your own words — it sends nothing to the citizen itself."

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    {
      projekt: projekt_title(projekt),
      url: projekt_url(projekt),
      runs_from: ::Whatsapp::DatePhrase.absolute(projekt.total_duration_start),
      runs_until: ::Whatsapp::DatePhrase.absolute(projekt.total_duration_end),
      projekt_settings: projekt_settings_of(projekt),
      phases: phases_of(projekt)
    }.compact_blank
  end

  private

    def projekt_settings_of(projekt)
      projekt.projekt_settings.reject { |setting| hidden_projekt_setting?(setting.key) }
        .map { |setting| row_for(key: setting.key, label: setting.short_name, value: setting.value) }
    end

    # Every phase a citizen may look at, in the order the projekt page shows
    # them, and closed ones included: "how long did I have" and "was that one
    # open to everybody" are asked after the fact at least as often as before it.
    def phases_of(projekt)
      projekt_phases_of(projekt).map do |projekt_phase|
        {
          projekt_phase_id: projekt_phase.id,
          phase: projekt_phase.title,
          starts_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.start_date),
          ends_on: ::Whatsapp::DatePhrase.absolute(projekt_phase.end_date),
          ends_in: ::Whatsapp::DatePhrase.relative(projekt_phase.end_date),
          running_now: projekt_phase.current?,
          # Named for what it actually decides. EligiblePhasesQuery answers
          # whether *the bot* can carry a submission into this phase, which is
          # narrower than whether the phase takes them at all: a phase with
          # submissions switched on but the chat flow off is open on the portal
          # and closed here. Reported as "open_for_submission" it would have the
          # model tell a citizen they cannot contribute to a phase they can.
          submission_through_this_chat:
            ::Whatsapp::EligiblePhasesQuery.eligible?(projekt_phase),
          who_may_take_part: participation_conditions(projekt_phase),
          limits: limits_of(projekt_phase),
          settings: settings_of(projekt_phase)
        }.compact
      end
    end

    def projekt_phases_of(projekt)
      projekt_phases = ::Whatsapp::ProjektPhasesQuery.call(projekt: projekt)

      ::ActiveRecord::Associations::Preloader.new.preload(projekt_phases, RESTRICTION_ASSOCIATIONS)

      projekt_phases
    end

    # The restrictions the phase applies, read through the same predicates
    # ProjektPhase#restriction_problem decides with — so what the citizen is told
    # and what a submission is refused for cannot come apart. Named in words
    # rather than as the raw enum: `user_status: 2` is not something the model can
    # answer a question from.
    def participation_conditions(projekt_phase)
      {
        account_required: projekt_phase.guest_participation? ? OFF : ON,
        verified_account_required: projekt_phase.user_status == "verified" ? ON : OFF,
        age_restriction: projekt_phase.age_restriction_formatted.presence,
        area_restriction: area_restriction_of(projekt_phase),
        street_restriction: projekt_phase.street_restrictions_formatted.presence,
        group_restriction: projekt_phase.individual_group_value_restriction_formatted.presence
      }.compact
    end

    # `geozone_restricted` names the kind of restriction and the affiliations name
    # its content, so both are needed for an answer: "only residents" with no list
    # is still a restriction, and a list with no kind is not one at all.
    def area_restriction_of(projekt_phase)
      kind = projekt_phase.geozone_restricted

      return if kind.blank? || kind == "no_restriction"

      [kind, projekt_phase.geozone_restrictions_formatted.presence].compact_blank.join(": ")
    end

    # Read off the phase's own accessors rather than out of the settings list
    # below, where they would arrive as the string "0" — which the model has no
    # way of reading as "no limit".
    def limits_of(projekt_phase)
      {
        max_submissions_per_user: positive_or_nil(projekt_phase.max_submissions_per_user),
        max_supports_per_user: positive_or_nil(projekt_phase.max_supports_per_user),
        review_before_publishing:
          projekt_phase.feature?("general.require_admin_acceptance") ? ON : OFF
      }.compact
    end

    def positive_or_nil(limit)
      limit.positive? ? limit : nil
    end

    def settings_of(projekt_phase)
      projekt_phase.settings.reject { |setting| hidden_setting?(setting.key) }
        .map do |setting|
          row_for(key: setting.key, label: setting.translated_name, value: setting.value)
        end
    end

    # The key travels with the label because the label is the portal's own
    # wording and a question is asked in the citizen's — a model that can see
    # both has two chances to recognise which setting was meant.
    #
    # A feature is on or off, never blank: an empty value is the answer "no" to
    # "is my contribution checked first", and dropped it would read as a setting
    # the projekt does not have.
    def row_for(key:, label:, value:)
      { setting: label.presence || key, key: key, value: rendered_value(key, value) }
    end

    def rendered_value(key, value)
      return value.present? ? ON : OFF if feature_key?(key)

      value.presence || UNSET
    end

    def feature_key?(key)
      key.start_with?("feature.", "projekt_feature.")
    end

    def hidden_setting?(key)
      return true if HIDDEN_SETTING_KEYS.include?(key)

      HIDDEN_SETTING_PATTERNS.any? { |pattern| key.match?(pattern) }
    end

    def hidden_projekt_setting?(key)
      HIDDEN_PROJEKT_SETTING_PATTERNS.any? { |pattern| key.match?(pattern) }
    end
end
