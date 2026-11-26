# The one way the final import starts. The import is marked submitting here, in
# the request, before the job is queued: every page rendered after the click
# must already see it running, and a second click while it runs must find it
# so, or the job runs twice and builds a second projekt.
class ProjektImports::StartSubmitService < ApplicationService
  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    started = projekt_import.with_lock do
      if projekt_import.submitting?
        next false
      end

      projekt_import.start_submit!(projekt_import.analysis_warnings)
      true
    end

    if !started
      return ServiceResult.failure(error: "import already submitting")
    end

    ProjektImports::ExecuteImportJob.perform_later(projekt_import.id)

    ServiceResult.success
  end

  private

    attr_reader :projekt_import
end
