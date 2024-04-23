# frozen_string_literal: true

class Shared::FollowIconComponent < ApplicationComponent
  delegate :current_user, :find_or_build_follow, :follow_text, :unfollow_text,
           :projekt_phase_feature?, :pick_text_color, to: :helpers

  def initialize(resource:)
    @resource = resource
  end

  def render?
    current_user &&
      !current_user&.guest? &&
      settings_allow?
  end

  private

    def settings_allow?
      case @resource
      when Proposal
        projekt_phase_feature?(@resource&.projekt_phase, "resource.show_follow_button_in_proposal_sidebar")
      else
        false
      end
    end

    def follow_obj
      @follow_obj ||= find_or_build_follow(current_user, @resource)
    end

    def follow_icon_html
      link_to follows_path(followable_id: @resource.id, followable_type: @resource.class.name, kind: "icon"),
          method: :post, remote: true, title: follow_text(@resource), style: "color:#{icon_color}" do
        helpers.content_tag(:i, nil, class: "far fa-bell")
      end
    end

    def unfollow_icon_html
      link_to follow_path(follow_obj, kind: "icon"), method: :delete, remote: true,
          title: unfollow_text(@resource), style: "color:#{icon_color}" do
        helpers.content_tag(:i, nil, class: "fas fa-bell")
      end
    end

    def icon_color
      pick_text_color(@resource&.sentiment&.color || "#004a83")
    end
end
