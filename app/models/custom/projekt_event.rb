class ProjektEvent < ApplicationRecord
  include Notifiable
  include Imageable
  include ResourceBelongsToProjekt

  belongs_to :old_projekt, class_name: "Projekt", foreign_key: "projekt_id" # TODO: remove column after data migration con1538

  delegate :projekt, to: :projekt_phase
  belongs_to :projekt_phase

  has_many :landing_page_resources, as: :resource, class_name: "LandingPageResource", dependent: :destroy
  has_many :landing_pages, through: :landing_page_resources, source: :landing_page

  validates :title, presence: true
  validates :datetime, presence: true

  default_scope { order(datetime: :asc) }

  scope :sort_by_all, -> {
    all
  }

  scope :sort_by_incoming, -> {
    where("COALESCE(end_datetime, datetime) >= ?", Time.zone.now)
  }

  scope :sort_by_past, -> {
    where("COALESCE(end_datetime, datetime) < ?", Time.zone.now)
  }

  scope :with_active_projekt, -> {
    joins(projekt_phase: :projekt).merge(Projekt.activated).merge(ProjektPhase.active)
  }

  def self.scoped_projekt_ids_for_footer(projekt)
    projekt
      .top_parent
      .all_children_projekts
      .unshift(projekt.top_parent)
      .ids
  end
end
