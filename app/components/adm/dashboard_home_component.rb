class Adm::DashboardHomeComponent < ApplicationComponent
  delegate :empty_state, :time_ago_in_words, to: :helpers

  attr_reader :team_members, :team_url, :recent_items, :recent_items_url, :recent_item_columns,
              :intro_text, :quick_links, :stats, :contact_persons, :notice,
              :activities, :section_settings_path

  def initialize(team_members:, team_url:, recent_items:, recent_items_url:, recent_item_columns: [],
                 intro_text: nil, quick_links: [], stats: [], contact_persons: nil,
                 notice: nil, activities: nil, section_settings_path: nil)
    @team_members = team_members
    @team_url = team_url
    @recent_items = recent_items
    @recent_items_url = recent_items_url
    @recent_item_columns = recent_item_columns
    @intro_text = intro_text
    @quick_links = quick_links || []
    @stats = stats || []
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
    contact_persons.present? && contact_persons.any?
  end

  def show_activities?
    activities.present? && activities.any?
  end

  def activity_description(activity)
    user_name = activity.user&.name || t(".activity_unknown_user")
    trackable_name = activity.metadata&.dig("trackable_name") || activity.trackable_type&.demodulize || "—"
    action_label = t(".activity_action_#{activity.action}", default: activity.action)
    "#{user_name} #{t('.activity_has')} #{trackable_name} #{action_label}"
  end

  def activity_time(activity)
    time_ago_in_words(activity.created_at)
  end
end
