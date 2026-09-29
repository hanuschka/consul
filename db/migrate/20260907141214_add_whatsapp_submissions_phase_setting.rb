class AddWhatsappSubmissionsPhaseSetting < ActiveRecord::Migration[6.1]
  PHASE_CLASSES = [ProjektPhase::ProposalPhase, ProjektPhase::BudgetPhase].freeze

  NEW_KEY = "feature.general.whatsapp_submissions".freeze

  # The WhatsApp bot used to accept a submission only into phases whose projekt
  # page had the AI drafting button switched on. It now reads a setting of its
  # own, which starts out mirroring that flag so no phase the bot serves today
  # goes dark on deploy.
  #
  # The value is written onto an existing row rather than only created: the
  # deploy runs projekt_phase_settings:add_new_settings as well, and whichever
  # of the two goes first, that one creates the row with the "off" default.
  def up
    PHASE_CLASSES.each do |phase_class|
      phase_class.includes(:settings).find_each do |projekt_phase|
        ai_flow_key = "feature.#{projekt_phase.ai_flow_feature_key}"
        ai_flow_setting = projekt_phase.settings.detect { |setting| setting.key == ai_flow_key }

        setting =
          projekt_phase.settings.detect { |candidate| candidate.key == NEW_KEY } ||
          projekt_phase.settings.build(key: NEW_KEY)
        setting.value = ai_flow_setting&.value.present? ? "active" : ""

        setting.save!
      end
    end
  end

  def down
    ProjektPhaseSetting.where(key: NEW_KEY).delete_all
  end
end
