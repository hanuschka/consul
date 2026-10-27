# The one place that knows which job gathers the material for which source, so
# starting an import and retrying one cannot drift apart.
class ProjektImports::DispatchSourceJob < ApplicationService
  JOBS = {
    "file" => ProjektImports::FromFileJob,
    "url" => ProjektImports::FromUrlJob,
    "consul_projekt" => ProjektImports::FromConsulProjektJob
  }.freeze

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    job = JOBS[projekt_import.source_kind]

    if job.blank?
      return ServiceResult.failure(
        error: "unknown import source #{projekt_import.source_kind}"
      )
    end

    job.perform_later(projekt_import.id)

    ServiceResult.success(job: job)
  end

  private

    attr_reader :projekt_import
end
