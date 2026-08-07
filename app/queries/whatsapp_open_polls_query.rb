class WhatsappOpenPollsQuery < ApplicationQuery
  def initialize(projekt: nil)
    @projekt = projekt
  end

  def call
    scope.includes(projekt_phase: { projekt: :page }).limit(::Whatsapp::MAX_LIST_ROWS).to_a
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
