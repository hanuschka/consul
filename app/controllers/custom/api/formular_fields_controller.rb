class Api::FormularFieldsController < Api::BaseController
  before_action :find_formular

  def index
    check_read_access!

    if phase_hidden_from_client?(@formular.projekt_phase)
      raise ForbiddenError, "Access denied"
    end

    formular_fields = paginate(@formular.formular_fields.includes(:translations))

    render json: {
      data: {
        formular_fields: FormularFieldSerializer.serialize_collection(formular_fields, client: current_client)
      },
      pagination: pagination_meta(formular_fields)
    }
  end

  private

    def find_formular
      @formular = Formular.find(params[:formular_id])
    end
end
