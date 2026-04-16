class Adm::Projekts::ManagerAssignmentsController < Adm::Projekts::BaseController
  before_action :find_projekt
  before_action :find_assignment

  def update
    authorize @assignment, policy_class: Adm::Projekts::ProjektManagerAssignmentPolicy

    if @assignment.update(assignment_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@assignment),
      partial: "adm/projekts/projekts/projekt_managers/assignment",
      locals: { projekt: @projekt, assignment: @assignment }
    )
  end

  private

    def find_projekt
      @projekt = Projekt.find(params[:projekt_id])
    end

    def find_assignment
      @assignment = @projekt.projekt_manager_assignments.find(params[:id])
    end

    def assignment_params
      params.require(:projekt_manager_assignment).permit(permissions: [])
    end
end
