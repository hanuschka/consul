class ProjektSetting < ApplicationRecord
  CONTENT_TIMESTAMP_KEYS = %w[
    projekt_feature.main.activate
    projekt_feature.general.show_in_navigation
    projekt_feature.general.show_in_overview_page
    projekt_feature.general.show_in_overview_page_navigation
    projekt_feature.general.show_in_homepage
    projekt_feature.general.show_in_individual_list
    projekt_feature.general.show_in_sidebar_filter
    projekt_feature.general.consider_underway
  ].freeze

  attr_accessor :form_field_disabled, :dependent_setting_ids, :dependent_setting_action
  belongs_to :projekt, touch: true

  validates :key, presence: true, uniqueness: { scope: :projekt_id }

  default_scope { order(id: :asc) }

  after_update :sync_related_projekt_children_active_setting, if: Proc.new { |setting| setting.key == "projekt_feature.main.activate" }
  after_update :touch_projekt_content_updated_at,
    if: Proc.new { |setting| setting.key.in?(CONTENT_TIMESTAMP_KEYS) && setting.saved_change_to_value? }
  after_update :trigger_sync_for_global_overview_related_projekt
  after_save :reset_visible_projekt_ids_cache
  after_destroy :reset_visible_projekt_ids_cache

  def prefix
    key.split(".").first
  end

  def type
    if %w[projekt_feature projekt_option projekt_newsfeed].include? prefix
      prefix
    else
      "configuration"
    end
  end

  def projekt_feature_prefix
    key.split(".").second
  end

  def projekt_feature_type
    if %w[main phase general sidebar debates proposals proposal_options polls budgets milestones].include? projekt_feature_prefix
      projekt_feature_prefix
    else
      "configuration"
    end
  end

  class << self

    def defaults
      {
        "projekt_feature.main.activate": "",

        "projekt_feature.general.show_in_navigation": "active",
        "projekt_feature.general.show_in_overview_page": "active",
        "projekt_feature.general.show_in_overview_page_navigation": "",
        "projekt_feature.general.show_in_homepage": "active",
        "projekt_feature.general.show_in_individual_list": "",
        "projekt_feature.general.allow_downvoting_comments": "active",
        "projekt_feature.general.show_in_sidebar_filter": 'active',
        "projekt_feature.general.consider_underway": "",
        "projekt_feature.general.allow_indexing": "active",
        "projekt_feature.general.show_related_projekt_link": "active",

        "projekt_option.general.external_participation_link": "",

        "projekt_feature.sidebar.show_notification_subscription_toggler": "active",
        "projekt_feature.sidebar.show_phases_in_projekt_page_sidebar": "active",
        "projekt_feature.sidebar.show_map": "active",
        "projekt_feature.sidebar.show_navigator_in_projekts_page_sidebar": "active",
        "projekt_feature.sidebar.projekt_page_sharing": "active",
        "projekt_feature.sidebar.new_resource_button_in_sidebar": "active",

        "projekt_custom_feature.default_footer_tab": nil
      }
    end

    def ensure_existence
      Projekt.all.each do |projekt|

        defaults.each do |name, value|
          unless find_by(key: name, projekt_id: projekt.id)
            self.create(key: name, value: value, projekt_id: projekt.id)
          end
        end
      end
    end

    def destroy_obsolete
      ProjektSetting.all.each{ |setting| setting.destroy unless defaults.keys.include?(setting.key.to_sym) }
    end

  end

  def enabled?
    value.present?
  end

  def short_name
    I18n.t("custom.settings.#{self.key}")
  end

  def sync_related_projekt_children_active_setting
    projekt.all_children_projekts.map do |child_projekt|
      child_projekt.projekt_settings.find_by( key: 'projekt_feature.main.activate' ).
        update(value: self.value)
    end
  end

  def touch_projekt_content_updated_at
    projekt.touch(:content_updated_at)
  end

  def trigger_sync_for_global_overview_related_projekt
    projekt.perform_sync_update_for_global_overview
  end

  def reset_visible_projekt_ids_cache
    Projekt.reset_visible_projekt_ids
  end
end
