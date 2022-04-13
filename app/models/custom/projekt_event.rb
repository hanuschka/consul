class ProjektEvent < ApplicationRecord
  belongs_to :projekt

  after_save do
    Projekt.all.each { |projekt| projekt.set_selectable_in_sidebar_selector('projekt_events', 'current') }
    Projekt.all.each { |projekt| projekt.set_selectable_in_sidebar_selector('projekt_events', 'expired') }
  end

  validates :title, presence: true

  def self.base_selection(scoped_projekt_ids = Projekt.ids)
    where(projekt_id: scoped_projekt_ids)
  end
end
