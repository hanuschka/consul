class SimilarContributions::MatchItemComponent < ApplicationComponent
  include SimilarContributionsMatchStatus

  # One row of a match wherever it is shown: the citizen's modal, the compact
  # list on the admin detail page and on the citizen's form, and the admin badge
  # popup. They differ in how large the picture is, how much of the description
  # is worth reading and what is offered underneath -- not in what a match is
  # made of.
  #
  # The audience is part of what a variant is, not of how it looks. An answer is
  # a valuator's or an admin's text and the citizen page publishes it only under
  # its own conditions, so a citizen variant must not receive it in the markup
  # at all -- hiding it in CSS would still ship it. A new variant copied from
  # the wrong row therefore renders nothing rather than leaking one.
  VARIANTS = {
    notice: { thumb_size: [360, 270], excerpt_words: 28, audience: :citizen },
    decision: { thumb_size: [360, 360], excerpt_words: 25, audience: :citizen },
    list: {
      thumb_size: [360, 360], excerpt_words: 25, audience: :admin,
      answer_excerpt_length: 300
    },
    popup: {
      thumb_size: [240, 240], excerpt_words: 20, audience: :admin,
      answer_excerpt_length: 160, processing_status: true
    }
  }.freeze

  PLACEHOLDER_ICON_CLASS = "fa-lightbulb".freeze

  renders_one :meta
  renders_one :footer

  attr_reader :resource, :variant

  def initialize(resource, variant:)
    @resource = resource
    @variant = variant
    @settings = VARIANTS.fetch(variant)
  end

  def css_class
    "similar-contributions-match -#{variant}"
  end

  def path
    helpers.similar_contributions_path_for(resource)
  end

  def image_attached?
    resource.image&.attachment&.attached?
  end

  def image_url
    resource.image.attachment_variant(
      resize_to_limit: settings[:thumb_size],
      format: "jpeg"
    )
  end

  def excerpt
    helpers.similar_contributions_excerpt(resource, words: settings[:excerpt_words])
  end

  def labels
    resource.projekt_labels
  end

  def sentiment_style
    helpers.sentiment_color_style(resource.sentiment)
  end

  # Whether the variant shows answers at all, so the template can tell an
  # unanswered contribution from one whose surface never shows answers.
  def shows_answer?
    admin? && settings[:answer_excerpt_length].present?
  end

  # An answer of nothing but an image or an embed has no text to excerpt, so
  # whether one exists is a separate question from whether it reads as one.
  def answer_present?
    answer.present?
  end

  def answer_excerpt
    return if answer.blank?

    @answer_excerpt ||= SimilarContributions::SearchTerms
      .strip_html(answer)
      .squish
      .truncate(settings[:answer_excerpt_length])
  end

  # What the copy button puts on the clipboard: the answer exactly as the
  # answer editor is handed it (admin/proposals/show.html.erb), so pasting it
  # there keeps the formatting the excerpt above has stripped off.
  def answer_html
    return if answer.blank?

    AdminWYSIWYGSanitizer.new.sanitize(answer)
  end

  def processing_status
    return unless admin? && settings[:processing_status]

    processing_status_for(resource)
  end

  private

    attr_reader :settings

    def admin?
      settings[:audience] == :admin
    end

    def answer
      return unless shows_answer?

      @answer ||= SimilarContributions::Scopes.answer_of(resource)
    end
end
