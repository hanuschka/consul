class Whatsapp::AskPhaseChoiceService < ApplicationService
  ROW_ID_PREFIX = "whatsapp_phase_".freeze

  def initialize(conversation:, projekt:, projekt_phases:)
    @conversation = conversation
    @projekt = projekt
    @projekt_phases = projekt_phases
  end

  def call
    @conversation.update!(step: "awaiting_phase_choice", projekt_phase_id: nil)
    @conversation.merge_context!(phase_choice_ids: @projekt_phases.map(&:id))

    Whatsapp::SendListService.call(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.choose_phase", projekt: @projekt.page&.title.presence || @projekt.name),
      button_label: I18n.t("whatsapp.bot.choose_phase_button"),
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

    def rows
      @projekt_phases.map do |phase|
        {
          id: self.class.row_id_for(phase.id),
          title: phase.title,
          description: end_date_description(phase)
        }
      end
    end

    def end_date_description(phase)
      return if phase.end_date.blank?

      I18n.t("whatsapp.bot.phase_row_description", end_date: I18n.l(phase.end_date.to_date))
    end
end
