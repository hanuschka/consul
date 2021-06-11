require_dependency Rails.root.join("app", "models", "geozone").to_s

class Geozone < ApplicationRecord
  has_many :projekt_phase_geozones
  has_many :projekt_phases, through: :projekt_phase_geozones
  has_many :projekts, through: :projekt_phases

  def safe_to_destroy?
    Geozone.reflect_on_all_associations(:has_many).all? do |association|
      if association.klass.name == 'User' || association.klass.name == 'ProjektPhaseGeozone'
        association.klass.where(geozone: self).empty?
      else
        association.klass.joins(:geozones).where('geozones.id = ?', self.id).empty?
      end
    end
  end
end
