class HealthcheckController < ActionController::Base
  def show
    head :ok
  end
end
