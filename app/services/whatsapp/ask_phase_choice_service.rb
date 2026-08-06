class Whatsapp::AskPhaseChoiceService < ApplicationService
  ROW_ID_PREFIX = "whatsapp_phase_".freeze

  # Without a projekt the list spans the whole portal, which changes what the
  # rows lead with but not how the answer is interpreted.
  def initialize(conversation:, projekt_phases:, projekt: nil)
    @conversation = conversation
    @projekt = projekt
    @projekt_phases = projekt_phases
  end

  def call
    @conversation.update!(step: "awaiting_phase_choice", projekt_phase_id: nil)
    @conversation.merge_context!(phase_choice_ids: @projekt_phases.map(&:id))

    Whatsapp::SendListService.call(
      account: @conversation.whatsapp_account,
      body: body,
      button_label: button_label,
      rows: rows
    )
  end

  def self.row_id_for(projekt_phase_id)
    "#{ROW_ID_PREFIX}#{projekt_phase_id}"
  end

  def self.projekt_phase_id_from_row(row_id)
    return if row_id.to_s.blank?
    return if !row_id.to_s.start_with?(ROW_ID_PREFIX)

    row_id.to_s.delete_prefix(ROW_ID_PREFIX).to_i
  end

  private

    def body
      return ::Whatsapp.welcome_greeting if @projekt.blank?

      I18n.t("whatsapp.bot.choose_phase", projekt: projekt_title(@projekt))
    end

    def button_label
      return I18n.t("whatsapp.bot.choose_projekt_button") if @projekt.blank?

      I18n.t("whatsapp.bot.choose_phase_button")
    end

    def rows
      @projekt_phases.map do |phase|
        {
          id: self.class.row_id_for(phase.id),
          title: row_title(phase),
          description: row_description(phase)
        }
      end
    end

    def row_title(phase)
      return phase.title if @projekt.present?

      projekt_title(phase.projekt)
    end

    # Across projekts the projekt name takes the title, so the phase name moves
    # into the description where the row still has room for it.
    def row_description(phase)
      return end_date_description(phase) if @projekt.present?
      return phase.title if phase.end_date.blank?

      I18n.t(
        "whatsapp.bot.projekt_row_description",
        phase: phase.title, end_date: I18n.l(phase.end_date.to_date)
      )
    end

    def end_date_description(phase)
      return if phase.end_date.blank?

      I18n.t("whatsapp.bot.phase_row_description", end_date: I18n.l(phase.end_date.to_date))
    end

    def projekt_title(projekt)
      projekt.page&.title.presence || projekt.name
    end
end
