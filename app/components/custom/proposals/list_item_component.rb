# frozen_string_literal: true

class Proposals::ListItemComponent < ApplicationComponent
  delegate :projekt_phase_feature?, to: :helpers
  attr_reader :proposal

  def initialize(proposal:, voted: nil)
    @proposal = proposal
    @sentiment = proposal.sentiment
    @voted = voted
  end

  def component_attributes
    {
      resource: @proposal,
      projekt: proposal.projekt,
      title: proposal.title,
      description: proposal.description,
      header_style: header_style,
      url: proposal_path
    }
  end

  def proposal_path
    helpers.proposal_path(proposal)
  end

  def date_formated
    return if proposal.published_at.nil?

    l(proposal.published_at, format: :date_only)
  end

  def header_style
    helpers.sentiment_color_style(@sentiment)
  end
end
