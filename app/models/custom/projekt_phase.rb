class ProjektPhase < ApplicationRecord
  belongs_to :projekt, optional: true
  has_many :projekt_phase_geozones, dependent: :destroy
  has_many :geozone_restrictions, through: :projekt_phase_geozones, source: :geozone

  after_update do
    Projekt.all.each { |projekt| projekt.update_selectable_in_sidebar_selectors }
  end

  def selectable_by?(user)
    geozone_allowed = geozone_restricted == "no_restriction" || geozone_restricted.nil? ||
                      ( geozone_restricted == "only_citizens" && user.present? && user.level_three_verified? ) ||
                      ( geozone_restricted == "only_geozones" && user.present? && user.level_three_verified? && geozone_restrictions.blank? ) ||
                      ( geozone_restricted == "only_geozones" && user.present? && user.level_three_verified? && geozone_restrictions.any? && geozone_restrictions.include?(user.geozone) )

    user.present? &&
      user.level_two_or_three_verified? &&
        projekt.current? &&
          geozone_allowed &&
            current?
  end

  def expired?
    end_date.present? && end_date < Date.today
  end

  def current?
    phase_activated? &&
      ((start_date <= Date.today if start_date.present?) || start_date.blank? ) &&
      ((end_date >= Date.today if end_date.present?) || end_date.blank? )
  end
end
