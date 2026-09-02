# Turns a projekt into the plain hash every copy is made from. A copy within
# this instance uses it as it stands; a cross-instance export is this bundle put
# through Projekts::Exporting::SanitizeBundle first. Serializing even the local
# case means there is exactly one shape the copiers ever read.
class Projekts::SerializeForCopy < ApplicationService
  # Bumped whenever the shape below changes in a way an older importer would
  # misread. An import refuses a version it does not know rather than
  # rebuilding half a projekt; a local copy always reads its own version.
  FORMAT_VERSION = 1

  def initialize(source:)
    @source = source
  end

  def call
    Projekts::Copying::Serializing::ProjektSerializer.call(source: source).merge(
      "format_version" => FORMAT_VERSION,
      "phases" => phase_nodes
    )
  end

  private

    attr_reader :source

    def phase_nodes
      source.projekt_phases.order(:given_order, :id).map do |projekt_phase|
        Projekts::Copying::Serializing::PhaseSerializer.call(source_phase: projekt_phase)
      end
    end
end
