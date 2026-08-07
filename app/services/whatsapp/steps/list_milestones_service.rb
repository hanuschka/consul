class Whatsapp::Steps::ListMilestonesService < ApplicationService
  DESCRIPTION_LENGTH = 200

  def initialize(conversation:, projekt: nil)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Steps::SendDigestService.call(
      conversation: @conversation,
      entries: entries,
      intro: I18n.t("whatsapp.bot.menu.milestones.intro"),
      empty_body: I18n.t("whatsapp.bot.menu.milestones.empty")
    )
  end

  private

    # Not every milestone carries a translated title, so the date is what the
    # entry falls back to — an untitled entry is worse than a dated one.
    def milestones
      @milestones ||= Whatsapp::PublishedMilestonesQuery.call(projekt: @projekt)
    end

    def entries
      milestones.map do |milestone|
        {
          title: milestone.title.presence || I18n.l(milestone.publication_date.to_date),
          description: description_for(milestone),
          url: phase_url_for(milestone)
        }
      end
    end

    def description_for(milestone)
      [
        I18n.l(milestone.publication_date.to_date),
        milestone.description.to_s.squish.presence&.truncate(DESCRIPTION_LENGTH)
      ].compact.join(" · ")
    end

    def phase_url_for(milestone)
      projekt_phase = projekt_phases[milestone.milestoneable_id]

      return if projekt_phase.blank?

      Whatsapp::ProjektLink.phase_url(projekt_phase)
    end

    # Loaded in one go: the milestones are polymorphic, so there is no
    # association to eager-load them through.
    def projekt_phases
      @projekt_phases ||=
        ProjektPhase
          .includes(projekt: :page)
          .where(id: milestones.map(&:milestoneable_id))
          .index_by(&:id)
    end
end
