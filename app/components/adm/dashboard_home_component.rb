class Adm::DashboardHomeComponent < ApplicationComponent
  delegate :empty_state, :kern_link_button, to: :helpers

  attr_reader :team_members, :team_url, :recent_items, :recent_items_url, :recent_item_columns,
              :recent_item_partial, :recent_item_headers, :recent_item_as,
              :intro_text, :quick_links, :stats, :contact_persons, :notice,
              :activities, :section_settings_path

  def initialize(team_members:, team_url:, recent_items:, recent_items_url:, recent_item_columns: [],
                 recent_item_partial: nil, recent_item_headers: [], recent_item_as: nil,
                 intro_text: nil, quick_links: [], stats: [], contact_persons: [],
                 notice: nil, activities: [], section_settings_path: nil)
    @team_members = team_members
    @team_url = team_url
    @recent_items = recent_items
    @recent_items_url = recent_items_url
    @recent_item_columns = recent_item_columns
    @recent_item_partial = recent_item_partial
    @recent_item_headers = recent_item_headers
    @recent_item_as = recent_item_as
    @intro_text = intro_text
    @quick_links = quick_links
    @stats = stats
    @contact_persons = contact_persons
    @notice = notice
    @activities = activities
    @section_settings_path = section_settings_path
  end

  def show_notice?
    notice.present? && notice.notice_active? && notice.notice_message.present?
  end

  def show_intro_or_stats?
    intro_text.present? || quick_links.any? || stats.any?
  end

  def show_contact_persons?
    contact_persons.any?
  end

  def show_recent?
    !recent_items.nil?
  end
end
