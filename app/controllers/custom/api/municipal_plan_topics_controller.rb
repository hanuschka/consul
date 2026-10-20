class Api::MunicipalPlanTopicsController < Api::BaseController
  before_action :check_read_access!
  before_action :check_module_enabled!

  def index
    topics = MunicipalPlan::Topic.includes(:translations)

    render json: { data: { municipal_plan_topics: MunicipalPlanTopicSerializer.serialize_collection(topics) }}
  end

  private

    def check_module_enabled!
      raise ActiveRecord::RecordNotFound if Setting["process.municipal_plans"].blank?
    end
end
