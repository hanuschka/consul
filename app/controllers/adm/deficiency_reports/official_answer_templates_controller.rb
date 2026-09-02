class Adm::DeficiencyReports::OfficialAnswerTemplatesController < Adm::DeficiencyReports::BaseController
  def index
    authorize DeficiencyReport::OfficialAnswerTemplate, :index?,
      policy_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy

    @official_answer_templates = policy_scope(DeficiencyReport::OfficialAnswerTemplate, policy_scope_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy::Scope)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.official_answer_templates"), icon: "description" }]
  end

  def new
    @official_answer_template = DeficiencyReport::OfficialAnswerTemplate.new
    authorize @official_answer_template, policy_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @official_answer_template = DeficiencyReport::OfficialAnswerTemplate.find(params[:id])
    authorize @official_answer_template, policy_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @official_answer_template = DeficiencyReport::OfficialAnswerTemplate.new(official_answer_template_params)
    authorize @official_answer_template, policy_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy

    if @official_answer_template.save
      redirect_to adm_deficiency_reports_official_answer_templates_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.official_answer_templates.new.title"))
      render :new
    end
  end

  def update
    @official_answer_template = DeficiencyReport::OfficialAnswerTemplate.find(params[:id])
    authorize @official_answer_template, policy_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy

    if @official_answer_template.update(official_answer_template_params)
      redirect_to adm_deficiency_reports_official_answer_templates_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.official_answer_templates.edit.title"))
      render :edit
    end
  end

  def destroy
    @official_answer_template = DeficiencyReport::OfficialAnswerTemplate.find(params[:id])
    authorize @official_answer_template, policy_class: Adm::DeficiencyReports::OfficialAnswerTemplatePolicy

    @official_answer_template.destroy!
    redirect_to adm_deficiency_reports_official_answer_templates_path
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.official_answer_templates.index.title"), url: adm_deficiency_reports_official_answer_templates_path, icon: "description" },
        { name: action_title }
      ]
    end

    def official_answer_template_params
      params.require(:deficiency_report_official_answer_template).permit(:title, :text)
    end
end
