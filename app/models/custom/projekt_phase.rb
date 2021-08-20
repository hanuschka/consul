class ProjektPhase < ApplicationRecord
  belongs_to :projekt, optional: true
  has_many :projekt_phase_geozones, dependent: :destroy
  has_many :geozone_restrictions, through: :projekt_phase_geozones, source: :geozone

  def selectable_by?(user)
    geozone_allowed = geozone_restricted == "no_restriction" ||
                      geozone_restricted == "only_citizens" ||
                      ( geozone_restricted == "only_geozones" && geozone_restrictions.blank? ) ||
                      ( geozone_restricted == "only_geozones" && geozone_restrictions.any? && user.present? && geozone_restrictions.include?(user.geozone) )

    user &&
      user.level_three_verified? &&
        geozone_allowed &&
          self.active &&
            ((self.start_date <= Date.today if self.start_date) || self.start_date.blank? ) &&
              ((self.end_date >= Date.today if self.end_date) || self.end_date.blank? )
  end

  def expired?
    end_date && end_date < Date.today
  end

  def currently_active?
    active &&
      ((start_date <= Date.today if start_date) || start_date.blank? ) &&
      ((end_date >= Date.today if end_date) || end_date.blank? )
  end
end
