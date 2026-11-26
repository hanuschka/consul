class PollSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[name summary description closing_note].freeze

  DISPLAY_SETTING_KEYS = {
    wizard_mode: "resource.wizard_mode",
    show_on_home_page: "resource.show_on_home_page",
    show_on_index_page: "resource.show_on_index_page",
    show_open_answer_author_name: "resource.show_open_answer_author_name"
  }.freeze

  PRELOADS = [
    :translations,
    :geozones,
    { budget: :translations },
    { image: { attachment_attachment: :blob } },
    { projekt_phase: [:settings, :translations, { projekt: { page: :translations } }] },
    { questions: Poll::QuestionSerializer::PRELOADS }
  ].freeze

  attr_reader :poll

  def initialize(poll, client: nil, vote_totals: nil)
    @poll = poll
    @client = client
    @vote_totals = vote_totals
  end

  def serialize
    poll_data = poll.as_json(
      only: [
        :id,
        :starts_at,
        :ends_at,
        :geozone_restricted,
        :published,
        :live,
        :show_summary_instead_of_questions,
        :budget_id,
        :created_at,
        :updated_at
      ]
    )

    poll_data.merge!(
      name: poll.name,
      summary: poll.summary,
      description: poll.description,
      closing_note: poll.closing_note,
      translations: serialize_translations(poll, TRANSLATED_ATTRIBUTES),
      **display_settings
    )

    if poll.projekt_phase.present?
      poll_data[:projekt_phase] = {
        id: poll.projekt_phase.id,
        title: poll.projekt_phase.phase_tab_name,
        type: poll.projekt_phase.type,
        projekt_id: poll.projekt_phase.projekt_id
      }

      if poll.projekt_phase.projekt.present?
        projekt = poll.projekt_phase.projekt
        poll_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if poll.geozone_restricted? && poll.geozones.any?
      poll_data[:geozones] = poll.geozones.map do |geozone|
        {
          id: geozone.id,
          name: geozone.name
        }
      end
    end

    if poll.budget.present?
      poll_data[:budget] = {
        id: poll.budget.id,
        name: poll.budget.name
      }
    end

    if poll.image.present?
      poll_data[:image] = ImageSerializer.new(poll.image, include_variants: false).serialize
    end

    if poll.questions.any?
      poll_data[:questions] = Poll::QuestionSerializer.serialize_collection(
        poll.questions,
        vote_totals: vote_totals
      )
    end

    poll_data
  end

  # Admin clients always see the vote counts; read-only clients only once
  # the public site shows the poll's results, and never for test votes.
  def self.results_visible?(poll, client, public_ability: ::Ability.new(nil))
    return true if client.present? && client.admin?
    return false if !poll.live?

    public_ability.can?(:results, poll)
  end

  def self.serialize_collection(polls, client: nil)
    public_ability = ::Ability.new(nil)
    polls_with_results = polls.select { |poll| results_visible?(poll, client, public_ability:) }
    question_ids = polls_with_results.flat_map { |poll| poll.questions.map(&:id) }
    vote_totals = Polls::AnswerVoteTotals.call(question_ids)

    polls.map do |poll|
      new(
        poll,
        client: client,
        vote_totals: polls_with_results.include?(poll) ? vote_totals : nil
      ).serialize
    end
  end

  private

    def vote_totals
      return @vote_totals if @vote_totals.present?
      return nil if !self.class.results_visible?(poll, client)

      @vote_totals = Polls::AnswerVoteTotals.call(poll.questions.map(&:id))
    end

    # Wizard mode and the display switches are phase settings; the poll
    # columns of the same names are no longer read.
    def display_settings
      projekt_phase = poll.projekt_phase

      DISPLAY_SETTING_KEYS.transform_values do |key|
        projekt_phase.present? && projekt_phase.feature?(key)
      end
    end
end
