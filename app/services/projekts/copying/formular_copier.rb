class Projekts::Copying::FormularCopier < ApplicationService
  def initialize(source_phase:, copy_phase:, record_copier:)
    @source_phase = source_phase
    @copy_phase = copy_phase
    @record_copier = record_copier
  end

  def call
    source_formular = Formular.find_by(projekt_phase_id: source_phase.id)
    return if source_formular.blank?

    # ProjektPhase::FormularPhase#create_formular already gave the copy an empty
    # formular; only phases of another type need one built here.
    copy_formular = Formular.find_or_create_by!(projekt_phase_id: copy_phase.id)

    record_copier.copy_all(
      source_formular.formular_fields,
      attributes: { formular_id: copy_formular.id },
      except: %w[formular_id]
    )

    # sent_at records a send that happened for the source's recipients.
    record_copier.copy_all(
      source_formular.formular_follow_up_letters,
      attributes: { formular_id: copy_formular.id, sent_at: nil },
      except: %w[formular_id sent_at]
    )
  end

  private

    attr_reader :source_phase, :copy_phase, :record_copier
end
