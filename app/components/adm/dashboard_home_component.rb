class Adm::DashboardHomeComponent < ApplicationComponent
  delegate :empty_state, :kern_link_button, to: :helpers

  attr_reader :team_members, :team_url,
              :intro_text, :quick_links, :stats, :contact_persons,
              :section, :notice_active, :notice_message,
              :activities, :activity_pagy, :section_settings_path,
              :tiles, :tiles_title, :tiles_icon, :tiles_hint

  def initialize(team_members:, team_url:,
                 intro_text: nil, quick_links: [], stats: [], contact_persons: [],
                 section: nil, notice_active: false, notice_message: nil,
                 activities: [], activity_pagy: nil, section_settings_path: nil,
                 tiles: [], tiles_title: nil, tiles_icon: "dashboard", tiles_hint: nil)
    @team_members = team_members
    @team_url = team_url
    @intro_text = intro_text
    @quick_links = quick_links
    @stats = stats
    @contact_persons = contact_persons
    @section = section
    @notice_active = notice_active
    @notice_message = notice_message
    @activities = activities
    @activity_pagy = activity_pagy
    @section_settings_path = section_settings_path
    @tiles = tiles
    @tiles_title = tiles_title
    @tiles_icon = tiles_icon
    @tiles_hint = tiles_hint
  end

  def show_notice?
    notice_active && notice_message.present?
  end

  def show_intro_or_stats?
    intro_text.present? || quick_links.any? || stats.any?
  end

  def show_contact_persons?
    contact_persons.any?
  end

  def show_tiles?
    tiles.any?
  end
end
