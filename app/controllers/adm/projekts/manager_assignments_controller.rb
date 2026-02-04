class Adm::Projekts::ManagerAssignmentsController < Adm::Projekts::BaseController
  def update
    @assignment = ProjektManagerAssignment.find(params[:id])
    authorize [:adm, :projekts, @assignment.projekt], :update?

    if @assignment.update(assignment_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@assignment),
      partial: "adm/projekts/projekts/projekt_managers/assignment",
      locals: { projekt: @assignment.projekt, assignment: @assignment }
    )
  end

  private

    def assignment_params
      params.require(:projekt_manager_assignment).permit(permissions: [])
    end
end
