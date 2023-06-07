class ProjektPhasesController < ApplicationController
  # include CustomHelper
  # include ProposalsHelper
  # include ProjektControllerHelper

  skip_authorization_check

  def selector_hint_html
    projekt_phase = ProjektPhase.find(params[:id])

    default_text = SiteCustomization::ContentBlock
      .custom_block_for("#{projekt_phase.resources_name}_creation_recommendations", I18n.locale)&.body&.html_safe || " "

    if projekt_phase.projekt_selector_hint.present?
      render html: projekt_phase.projekt_selector_hint.html_safe
    else
      render html: default_text
    end
  end

  def form_heading_text
    projekt_phase = ProjektPhase.find(params[:id])
    default_text = t("#{projekt_phase.resources_name}.new.start_new")

    if projekt_phase.resource_form_title.present?
      render html: projekt_phase.resource_form_title.html_safe
    else
      render html: default_text
    end
  end
end
