class Whatsapp::Archive::PhaseMenuService < ApplicationService
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    ::Whatsapp::Archive::SendMenuService.call(
      conversation: @conversation,
      scope: :phase,
      record_id: @projekt_phase.id,
      body: body,
      available_actions: available_actions
    )
  end

  private

    def body
      [
        "*#{@projekt_phase.title}*",
        Whatsapp::ProjektLink.title(@projekt_phase.projekt),
        end_date_line
      ].compact_blank.join("\n")
    end

    def end_date_line
      return if @projekt_phase.end_date.blank?

      I18n.t("whatsapp.archive.menu.phase.until", end_date: I18n.l(@projekt_phase.end_date.to_date))
    end

    def user
      @conversation.user
    end

    def available_actions
      actions = [:page]

      actions << :participate if participation_open?
      actions << :contributions if phase_contributions.any?
      actions << :results if Whatsapp::PublishedResultsQuery.public_section_for(@projekt_phase).present?

      actions
    end

    # The same eligibility the submission flow enforces, asked before the row is
    # offered rather than after it is tapped.
    def participation_open?
      return false if user.blank?
      return false if !Whatsapp::EligiblePhasesQuery.eligible?(@projekt_phase)

      Whatsapp::ResourceCreationValidationService.call(
        projekt_phase: @projekt_phase, user: user
      ).blank?
    end

    def phase_contributions
      @phase_contributions ||=
        Whatsapp::PhaseContributionsQuery.call(projekt_phase: @projekt_phase)
    end
end
