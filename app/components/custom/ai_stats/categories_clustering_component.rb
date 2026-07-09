class AiStats::CategoriesClusteringComponent < ApplicationComponent
  TOPIC_COLORS = %w[#D4A017 #4A7C2F #2E6B8A #7B4B94 #C75B39 #3D7A6B #8B5A2B #5C6BC0].freeze

  renders_one :bottom_content

  def initialize(clustering_data:, title_key:, resource_class: Proposal)
    @clustering_data = clustering_data || {}
    @title_key = title_key
    @resource_class = resource_class
  end

  def title_key
    @title_key
  end

  def cluster_modifier_class
    case @title_key
    when "custom.ai_stats.topic_clustering"
      "ai-clustering--topic"
    when "custom.ai_stats.semantic_clustering"
      "ai-clustering--semantic"
    end
  end

  def categories
    return @clustering_data if @clustering_data.is_a?(Array)

    @clustering_data.values
  end

  def render?
    categories.any?
  end

  def total_resources_count
    categories.sum { |c| resource_count(c) }
  end

  def total_categories_count
    categories.size
  end

  def category_color(index)
    TOPIC_COLORS[index % TOPIC_COLORS.length]
  end

  def subcategory_count(category)
    category["subtopics"]&.size || 0
  end

  def resource_count(category)
    # binding.pry
    category["subtopics"]&.sum { |s| (s["resource_ids"] || s["proposal_ids"])&.size || 0 } || 0
  end

  def subcategory_resource_count(subcategory)
    (subcategory["resource_ids"] || subcategory["proposal_ids"])&.size || 0
  end

  def resources_for_subcategory(subcategory)
    resource_ids = subcategory["resource_ids"] || subcategory["proposal_ids"] || []
    return [] if resource_ids.empty?

    query = @resource_class.where(id: resource_ids)
    query = query.base_selection if @resource_class.respond_to?(:base_selection)

    if @resource_class == Comment
      comments = query.includes(:user, :translations, :commentable).to_a
      budget_commentables = comments.filter_map(&:commentable).select do |commentable|
        commentable.is_a?(Budget::Investment)
      end

      ActiveRecord::Associations::Preloader.new.preload(budget_commentables, :budget)

      comments
    elsif @resource_class == Budget::Investment
      query.includes(
        :translations,
        :budget,
        image: { attachment_attachment: :blob },
        projekt_labels: :translations,
        sentiment: :translations
      )
    else
      query.includes(
        :translations,
        image: { attachment_attachment: :blob },
        projekt_labels: :translations,
        sentiment: :translations
      )
    end
  end

  def resource_image_url(resource)
    return nil unless resource.image&.attached?

    resource.image.variant(:thumb2)
  end

  def resource_path(resource)
    if resource.is_a?(Budget::Investment)
      Rails.application.routes.url_helpers.budget_investment_path(resource.budget, resource)
    elsif resource.is_a?(Comment)
      commentable = resource.commentable
      if commentable.is_a?(Proposal)
        Rails.application.routes.url_helpers.proposal_path(commentable, anchor: "comment_#{resource.id}")
      elsif commentable.is_a?(Budget::Investment)
        Rails.application.routes.url_helpers.budget_investment_path(commentable.budget, commentable, anchor: "comment_#{resource.id}")
      else
        "#"
      end
    else
      Rails.application.routes.url_helpers.proposal_path(resource)
    end
  end

  def resource_has_image?(resource)
    return false if resource.is_a?(Comment)

    resource.image&.attached?
  end

  def resource_title(resource)
    return resource.body.to_s.truncate(140) if resource.is_a?(Comment)

    resource.title
  end

  def resource_labels(resource)
    return [] if resource.is_a?(Comment)

    resource.projekt_labels
  end

  def resource_sentiment(resource)
    return nil if resource.is_a?(Comment)

    resource.sentiment
  end
end

