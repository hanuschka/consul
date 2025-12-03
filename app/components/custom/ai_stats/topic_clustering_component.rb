class AiStats::TopicClusteringComponent < ApplicationComponent
  TOPIC_COLORS = %w[#D4A017 #4A7C2F #2E6B8A #7B4B94 #C75B39 #3D7A6B #8B5A2B #5C6BC0].freeze

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @topic_clustering = projekt_phase.ai_stats&.dig("topic_clustering") || {}
  end

  def topics
    @topic_clustering["topics"] || []
  end

  def render?
    topics.any?
  end

  def total_proposals_count
    topics.sum { |t| proposal_count(t) }
  end

  def total_topics_count
    topics.size
  end

  def topic_color(index)
    TOPIC_COLORS[index % TOPIC_COLORS.length]
  end

  def subtopic_count(topic)
    topic["subtopics"]&.size || 0
  end

  def proposal_count(topic)
    topic["subtopics"]&.sum { |s| s["proposal_ids"]&.size || 0 } || 0
  end

  def subtopic_proposal_count(subtopic)
    subtopic["proposal_ids"]&.size || 0
  end

  def proposals_for_subtopic(subtopic)
    proposal_ids = subtopic["proposal_ids"] || []
    return [] if proposal_ids.empty?

    Proposal.base_selection.where(id: proposal_ids).includes(image: { attachment_attachment: :blob })
  end

  def proposal_image_url(proposal)
    return nil unless proposal.image&.attached?

    proposal.image.variant(:thumb2)
  end

  def proposal_path(proposal)
    Rails.application.routes.url_helpers.proposal_path(proposal)
  end
end


