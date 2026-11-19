class Api::DeficiencyReportAnswerTemplatesController < Api::BaseController
  def index
    check_admin_access!
    answer_templates = paginate(DeficiencyReport::OfficialAnswerTemplate.all)
    serialized_answer_templates = answer_templates.map do |answer_template|
      answer_template.as_json(only: [:id, :title, :text, :created_at, :updated_at])
    end

    render json: {
      data: { deficiency_report_answer_templates: serialized_answer_templates },
      pagination: pagination_meta(answer_templates)
    }
  end
end
