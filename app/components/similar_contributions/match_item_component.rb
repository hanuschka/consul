class SimilarContributions::MatchItemComponent < ApplicationComponent
  # One row of a match wherever it is shown: the citizen's modal, the compact
  # list on the admin detail page and on the citizen's form, and the admin badge
  # popup. They differ in how large the picture is, how much of the description
  # is worth reading and what is offered underneath -- not in what a match is
  # made of.
  VARIANTS = {
    notice: { thumb_size: [360, 270], excerpt_words: 28 },
    list: { thumb_size: [360, 360], excerpt_words: 25 },
    popup: { thumb_size: [240, 240], excerpt_words: 20 }
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

  private

    attr_reader :settings
end
