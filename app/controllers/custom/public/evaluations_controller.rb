class Public::EvaluationsController < ApplicationController
  skip_authorization_check
  layout "public_evaluation"

  def show
    @evaluation = ProjektEvaluation.completed.find_by!(share_token: params[:token])
    @projekt = @evaluation.projekt
  end
end
