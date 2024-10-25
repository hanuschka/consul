class DeficiencyReportManagement::OfficialAnswerTemplatesController < DeficiencyReportManagement::BaseController
  load_and_authorize_resource :official_answer_template, class: "DeficiencyReport::OfficialAnswerTemplate", except: :show

  def index; end

  def new; end

  def edit; end

  def create
    @official_answer_template = DeficiencyReport::OfficialAnswerTemplate.new(official_answer_template_params)

    if @official_answer_template.save
      redirect_to deficiency_report_management_official_answer_templates_path
    else
      render :new
    end
  end

  def update
    if @official_answer_template.update(official_answer_template_params)
      redirect_to deficiency_report_management_official_answer_templates_path
    else
      render :edit
    end
  end

  def destroy
    if @official_answer_template.safe_to_destroy?
      @official_answer_template.destroy!
    end

    redirect_to deficiency_report_management_official_answer_templates_path
  end

  private

    def official_answer_template_params
      params.require(:deficiency_report_official_answer_template).permit(
        :title, :text
      )
    end
end
