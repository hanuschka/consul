class Ai::Tools::WhatsappAiAssistant::ListMilestones < Ai::Tools::WhatsappAiAssistant::BaseTool
  DESCRIPTION_LENGTH = 200

  description "Lists the progress the portal has published — milestones already reached, newest " \
              "first, each with the link to the phase it belongs to. Name a project for its own " \
              "progress, or pass null for the whole portal. Only milestones already reached are " \
              "returned: a dated one still in the future is a plan, not progress, and must not be " \
              "reported as something that happened. Returns facts for you to answer in your own " \
              "words — it sends nothing to the citizen itself."

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
  end

  def execute(projekt_name: nil)
    for_named_projekt(projekt_name) do |projekt|
      @milestones = ::Whatsapp::PublishedMilestonesQuery.call(projekt: projekt)

      { milestones: @milestones.map { |milestone| row_for(milestone) }}
    end
  end

  private

    # Not every milestone carries a translated title, so the date is what the
    # entry falls back to — an untitled entry is worse than a dated one.
    def row_for(milestone)
      {
        title: milestone.title.presence || I18n.l(milestone.publication_date.to_date),
        published_on: milestone.publication_date.to_date.iso8601,
        description: milestone.description.to_s.squish.presence&.truncate(DESCRIPTION_LENGTH),
        projekt: projekt_title_for(milestone),
        url: phase_url_for(milestone)
      }.compact
    end

    # Named even when the citizen asked about one projekt: the portal-wide call
    # returns milestones from several, and a list of progress with no projekt
    # against each entry cannot be answered from.
    def projekt_title_for(milestone)
      projekt = projekt_phase_for(milestone)&.projekt

      return if projekt.blank?

      projekt_title(projekt)
    end

    def phase_url_for(milestone)
      projekt_phase = projekt_phase_for(milestone)

      return if projekt_phase.blank?

      ::Whatsapp::ProjektLink.phase_url(projekt_phase)
    end

    def projekt_phase_for(milestone)
      projekt_phases[milestone.milestoneable_id]
    end

    # Loaded in one go: the milestones are polymorphic, so there is no
    # association to eager-load them through.
    def projekt_phases
      @projekt_phases ||=
        ::ProjektPhase
          .includes(projekt: :page)
          .where(id: @milestones.map(&:milestoneable_id))
          .index_by(&:id)
    end
end
