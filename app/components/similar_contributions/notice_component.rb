class SimilarContributions::NoticeComponent < ApplicationComponent
  EXCERPT_LENGTH = 220
  IMAGE_THUMB_SIZE = [360, 270].freeze
  IMAGE_THUMB_SIZE_2X = [720, 540].freeze
  PLACEHOLDER_ICON_CLASS = "fa-lightbulb".freeze

  attr_reader :matches, :resource

  def initialize(matches, resource:)
    @matches = Array(matches)
    @resource = resource
  end

  def render?
    matches.any?
  end

  def publish_url
    if resource.is_a?(::Budget::Investment)
      publish_draft_budget_investment_path(resource.budget, resource)
    else
      publish_draft_proposal_path(resource)
    end
  end

  def excerpt_for(match_resource)
    SimilarContributions::SearchTerms
      .strip_html(match_resource.description)
      .squish
      .truncate(EXCERPT_LENGTH)
  end

  def image_visible_for?(match_resource)
    helpers.form_attached_image_visible?(match_resource)
  end

  def image_component_for(match_resource)
    image = match_resource.image

    Shared::ResourceImageComponent.new(
      image_url: image_variant(image, IMAGE_THUMB_SIZE),
      image_url_2x: image_variant(image, IMAGE_THUMB_SIZE_2X),
      image_placeholder_icon_class: PLACEHOLDER_ICON_CLASS,
      resource: match_resource,
      ai_generated: image&.ai_generated?
    )
  end

  def sentiment_style_for(match_resource)
    helpers.sentiment_color_style(match_resource.sentiment)
  end

  def votes_container_id(match_resource)
    "#{dom_id(match_resource)}_votes"
  end

  def path_for(match_resource)
    if match_resource.is_a?(::Budget::Investment)
      budget_investment_path(match_resource.budget, match_resource)
    else
      proposal_path(match_resource)
    end
  end

  def supporting_available?(match_resource)
    projekt_phase = match_resource.projekt_phase

    return false if projekt_phase.blank?

    projekt_phase_feature?(projekt_phase, "resource.allow_voting")
  end

  def votes_component_for(match_resource)
    if match_resource.is_a?(::Budget::Investment)
      ::Budgets::Investments::VotesComponent.new(match_resource)
    else
      ::Proposals::NewVotesComponent.new(
        match_resource,
        vote_url: vote_proposal_path(match_resource, value: "yes")
      )
    end
  end

  private

    def image_variant(image, size)
      return if image.blank?

      image.attachment_variant(
        coalesce: true,
        resize_to_fill: size,
        saver: { quality: 85 },
        format: "jpeg"
      )
    end
end
