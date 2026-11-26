load Rails.root.join("app", "controllers", "legislation", "processes_controller.rb")

class Legislation::ProcessesController < Legislation::BaseController
  def show
    draft_version = @process.draft_versions.published.last
    allegations_phase = @process.allegations_phase

    if allegations_phase.enabled? && allegations_phase.started? && draft_version.present?
      redirect_to legislation_process_draft_version_path(@process, draft_version)
    elsif @process.debate_phase.enabled?
      redirect_to debate_legislation_process_path(@process)
    elsif @process.proposals_phase.enabled?
      redirect_to proposals_legislation_process_path(@process)
    else
      redirect_to allegations_legislation_process_path(@process)
    end
  end
end
