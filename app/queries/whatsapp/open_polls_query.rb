class Whatsapp::OpenPollsQuery < ApplicationQuery
  def initialize(projekt: nil, from: 0)
    @projekt = projekt
    @from = from
  end

  def call
    scope
      .includes(projekt_phase: { projekt: :page })
      .offset(::Whatsapp::ListWindow.offset(@from))
      .limit(::Whatsapp::ListWindow::ROWS)
      .to_a
  end

  def total
    scope.count
  end

  def exists?
    scope.exists?
  end

  private

    def scope
      relation = Poll
        .current
        .joins(projekt_phase: { projekt: :page })
        .where(site_customization_pages: { status: "published" })
        .merge(Projekt.activated)
        .order(:ends_at)

      return relation if @projekt.blank?

      relation.where(projekt_phases: { projekt_id: @projekt.id })
    end
end
