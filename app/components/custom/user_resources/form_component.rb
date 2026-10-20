class UserResources::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper

  delegate :suggest_data, :current_user, :projekt_phase_feature?, to: :helpers

  attr_reader :resource

  def initialize(resource, url:, title:, embbeded_in_ai_flow: false)
    @resource = resource
    @title = title
    @url = url
    @embbeded_in_ai_flow = embbeded_in_ai_flow
  end

  # The AI flow's step-2 loader hangs off the form it wraps, so the hook only
  # exists on the embedded render.
  def form_css_class
    classes = ["js-rich-text-form", "user-resource-form"]
    classes << "js-ai-flow-step2-form" if @embbeded_in_ai_flow

    classes.join(" ")
  end

  def similar_contributions_check_running?
    resource.persisted? && resource.similar_contributions_check_processing?
  end

  def render?
    return true unless resource.is_a?(Debate) || resource.is_a?(Proposal)

    projekt_phase.present?
  end

  def projekt_phase
    return nil unless resource.is_a?(Debate) || resource.is_a?(Proposal)

    @projekt_phase ||= resource.projekt_phase
  end

  def back_link
    case @resource
    when Debate
      debates_back_link_path
    when Proposal
      proposals_back_link_path
    end
  end

  def i18n_scope
    case @resource
    when Debate
      "debates"
    when Proposal
      "proposals"
    when Idea
      "ideas"
    end
  end

  def debates_back_link_path
    helpers.resources_back_link(fallback_path: debates_path)
  end

  def proposals_back_link_path
    helpers.resources_back_link(fallback_path: proposals_path)
  end

  def title_max_length
    case resource
    when Debate
      Debate.title_max_length
    else
      Proposal.title_max_length
    end
  end

  def banner_class_name
    "-#{resource.class.name.downcase}"
  end

  def base_class_name
    class_name = ""

    unless helpers.projekt_phase_feature?(projekt_phase, "form.allow_attached_image") || resource.is_a?(Idea)
      class_name += " -no-image"
    end

    class_name
  end

  def form_title
    projekt_phase&.resource_form_title&.presence || @title
  end

  def title_placeholder
    projekt_phase&.resource_form_title_placeholder&.presence || t("custom.#{i18n_scope}.form.title_placeholder")
  end

  def description_placeholder
    projekt_phase&.resource_form_description_placeholder&.presence || t("custom.#{i18n_scope}.form.description_placeholder")
  end

  def show_labels_selector?
    return false unless projekt_phase.present?

    projekt_phase.labels_selector_available?
  end

  def show_sentiments_selector?
    return false unless projekt_phase.present?

    projekt_phase_feature?(projekt_phase, "form.sentiments")
  end

  def show_idea_category_selector?
    resource.is_a?(Idea) && Idea::Category.exists?
  end

  def show_documents_input?
    return ideas_feature?("document_upload") if resource.is_a?(Idea)

    projekt_phase_feature?(projekt_phase, "form.allow_attached_documents")
  end

  def show_external_video_input?
    return ideas_feature?("external_video") if resource.is_a?(Idea)

    projekt_phase_feature?(projekt_phase, "form.enable_external_video")
  end

  def show_image_input?
    return true if resource.is_a?(Idea)

    projekt_phase_feature?(projekt_phase, "form.allow_attached_image")
  end

  def show_map_input?
    return true if resource.is_a?(Idea)

    projekt_phase_feature?(projekt_phase, "form.show_map") || @resource&.map_location.present?
  end

  def map_location
    resource.map_location ||
      resource.build_map_location(
        latitude: resource&.projekt_phase&.map_location&.latitude,
        longitude: resource&.projekt_phase&.map_location&.longitude,
        zoom: resource&.projekt_phase&.map_location&.zoom
      )
  end

  def show_sidebar?
    !@embbeded_in_ai_flow
  end

  def show_back_button?
    !@embbeded_in_ai_flow
  end
end
