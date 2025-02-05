class UserResources::FormComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper

  delegate :suggest_data, :current_user, :projekt_phase_feature?, to: :helpers

  attr_reader :resource

  def initialize(resource, url:, title:)
    @resource = resource
    @title = title
    @url = url
  end

  def render?
    projekt_phase.present?
  end

  def projekt_phase
    resource.projekt_phase
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

  def max_description_lenght
    case resource
    when Debate
      Debate.description_max_length
    else
      2000
    end
  end

  def banner_class_name
    "-#{resource.class.name.downcase}"
  end

  def base_class_name
    class_name = ""

    if !helpers.projekt_phase_feature?(projekt_phase, "form.allow_attached_image")
      class_name += " -no-image"
    end

    class_name
  end

  def form_title
    projekt_phase.resource_form_title.presence || @title
  end

  def descriotion_placeholder
    projekt_phase.resource_form_title_hint.presence || t("custom.#{i18n_scope}.form.description_placeholder")
  end

  def show_labels_selector?
    projekt_phase_feature?(projekt_phase, "form.labels")
  end

  def show_sentiments_selector?
    projekt_phase_feature?(projekt_phase, "form.sentiments")
  end

  def show_documents_input?
    projekt_phase_feature?(projekt_phase, "form.allow_attached_documents")
  end

  def show_external_video_input?
    projekt_phase_feature?(projekt_phase, "form.enable_external_video")
  end

  def show_post_on_behalf_of_input?
    helpers.allowed_to_post_on_behalf_of?(current_user, projekt_phase.projekt)
  end

  def show_image_input?
    projekt_phase_feature?(projekt_phase, "form.allow_attached_image")
  end

  def show_map_input?
    projekt_phase_feature?(projekt_phase, "form.show_map") || @resource.try(:map_location).present?
  end
end
