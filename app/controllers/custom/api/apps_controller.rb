class Api::AppsController < Api::BaseController
  skip_authorization_check
  before_action :find_app, only: [:update]

  def update
    if @app.update(app_params)

      head :ok
    else
      head :error
    end
  end

  private

  def find_app
    @app = App.find_or_create_by(params[:codename])
  end

  def app_params
    params.require(:app).permit(:status)
  end
end
