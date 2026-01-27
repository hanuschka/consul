# frozen_string_literal: true

class Proposals::ListItemComponent < ApplicationComponent
  delegate :projekt_phase_feature?, to: :helpers
  attr_reader :proposal

  def initialize(proposal:, voted: nil, additional_url_params: nil)
    @proposal = proposal
    @sentiment = proposal.sentiment
    @voted = voted
    @additional_url_params = additional_url_params
  end

  def component_attributes
    {
      resource: @proposal,
      projekt: proposal.projekt,
      title: proposal.title,
      description: proposal.description,
      header_style: header_style,
      tags: proposal.tags.first(3),
      url: proposal_path,
      image_url: proposal.image&.variant(:card_thumb),
      image_placeholder_icon_class: "fa-lightbulb",
      no_footer_bottom_padding: true
    }
  end

  def proposal_path
    if @additional_url_params.present? && @additional_url_params[:landing_page].present?
      helpers.landing_page_proposal_path(
        landing_page_slug: @additional_url_params[:landing_page],
        id: proposal.id
      )
    else
      helpers.proposal_path(proposal)
    end
  end

  def date_formated
    return if proposal.published_at.nil?

    l(proposal.published_at, format: :date_only)
  end

  def header_style
    helpers.sentiment_color_style(@sentiment)
  end
end
