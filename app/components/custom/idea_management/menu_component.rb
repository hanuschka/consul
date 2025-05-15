class IdeaManagement::MenuComponent < ApplicationComponent
  include LinkListHelper
  delegate :current_user, :can?, :link_list, to: :helpers

  def initialize
  end

  def links
    [
      ideas_link,
      settings_link,
    ].compact
  end

  private

    def ideas_link
      return unless can?(:index, Idea)

      [
        t("custom.admin.menu.ideas.list"),
        idea_management_ideas_path,
        controller_name == "ideas"
      ]
    end

    def settings_link
      return unless can?(:manage, Idea)

      [
        t("custom.admin.menu.ideas.settings"),
        idea_management_settings_path,
        controller_name == "settings"
      ]
    end
end
