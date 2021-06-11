class ProjektSetting < ApplicationRecord
  belongs_to :projekt

  validates :key, presence: true, uniqueness: { scope: :projekt_id }

  default_scope { order(id: :asc) }

  def prefix
    key.split(".").first
  end

  def type
    if %w[projekt_feature projekt_newsfeed].include? prefix
      prefix
    else
      "configuration"
    end
  end

  def projekt_feature_prefix
    key.split(".").second
  end

  def projekt_feature_type
    if %w[general sidebar footer].include? projekt_feature_prefix
      projekt_feature_prefix
    else
      "configuration"
    end
  end

  class << self

    def defaults
      {
        "projekt_feature.general.show_in_navigation": nil,
        "projekt_feature.general.show_not_active_phases_in_projekts_page_sidebar": nil,

        "projekt_feature.sidebar.projekt_page_sharing": 'active',
        "projekt_feature.sidebar.show_phases_in_projekt_page_sidebar": 'active',
        "projekt_feature.sidebar.show_total_duration_in_projekts_page_sidebar": 'active',
        "projekt_feature.sidebar.show_navigator_in_projekts_page_sidebar": true,

        "projekt_feature.footer.show_projekt_footer": 'active',
        "projekt_feature.footer.show_comments_in_projekt_footer": 'active',
        "projekt_feature.footer.show_notifications_in_projekt_footer": nil,
        "projekt_feature.footer.show_milestones_in_projekt_footer": nil,
        "projekt_feature.footer.show_newsfeed_in_projekt_footer": nil,

        "projekt_newsfeed.id": nil,
        "projekt_newsfeed.type": nil
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

  end

  def enabled?
    value.present?
  end

end
