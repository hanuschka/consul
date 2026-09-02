class Projekts::Copying::FormularCopier < ApplicationService
  def initialize(node:, copy_phase:, record_copier:)
    @node = node
    @copy_phase = copy_phase
    @record_copier = record_copier
  end

  def call
    return if node.blank?

    # ProjektPhase::FormularPhase#create_formular already gave the copy an empty
    # formular; only phases of another type need one built here.
    copy_formular = Formular.find_or_create_by!(projekt_phase_id: copy_phase.id)

    record_copier.copy_all(
      node["fields"],
      attributes: { formular_id: copy_formular.id }
    )

    record_copier.copy_all(
      node["follow_up_letters"],
      attributes: { formular_id: copy_formular.id }
    )
  end

  private

    attr_reader :node, :copy_phase, :record_copier
end
