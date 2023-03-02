module UserResource
  class FormComponent < ApplicationComponent
    include TranslatableFormHelper
    include GlobalizeHelper

    delegate :suggest_data, to: :helpers
    delegate :current_user, to: :helpers

    attr_reader :resource

    def initialize(resource, url:, title:, selected_projekt:, categories:)
      @resource = resource
      @title = title
      @url = url
      @selected_projekt = selected_projekt
      @categories = categories
    end

    def back_path
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
      if params[:origin] == 'projekt'
        projekt = Projekt.find(params[:projekt_id])
        page = projekt.page
        debate_phase_id = projekt.debate_phase.id

        link_to "/#{page.slug}?selected_phase_id=#{debate_phase_id}", class: "back" do
          tag.span(class: "icon-angle-left") + t("shared.back")
        end

      else
        back_link_to debates_path
      end
    end

    def proposals_back_link_path
      if params[:origin] == 'projekt'
        projekt = Projekt.find(params[:projekt_id])
        page = projekt.page
        proposal_phase_id = projekt.proposal_phase.id

        link_to "/#{page.slug}?selected_phase_id=#{proposal_phase_id}", class: "back" do
          tag.span(class: "icon-angle-left") + t("shared.back")
        end

      else
        back_link_to proposals_path
      end
    end
  end
end
