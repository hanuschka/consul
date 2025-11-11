class DeficiencyReports::FeedbackFormController < ApplicationController
  include FeatureFlags
  feature_flag :deficiency_reports

  before_action :authenticate_user!

  def new
    @deficiency_report = DeficiencyReport.find(params[:deficiency_report_id])

    if @deficiency_report.feedback_form.present?
      redirect_to deficiency_report_path(@deficiency_report),
        alert: t("custom.deficiency_reports.feedback_form.new.already_submitted")
    end

    @deficiency_report_feedback_form = DeficiencyReport::FeedbackForm.new(
                                         deficiency_report: @deficiency_report
                                       )
    authorize! :create, @deficiency_report_feedback_form
  end

  def create
    @deficiency_report = DeficiencyReport.find(params[:deficiency_report_id])
    @deficiency_report_feedback_form = DeficiencyReport::FeedbackForm.new(
                                         feedback_params.merge(deficiency_report: @deficiency_report)
                                       )
    authorize! :create, @deficiency_report_feedback_form

    if @deficiency_report_feedback_form.save
      redirect_to deficiency_report_path(@deficiency_report),
        notice: t("custom.deficiency_reports.feedback_form.create.success")
    else
      render :new
    end
  end

  private

    def feedback_params
      params.require(:deficiency_report_feedback_form).permit(
        %w[overall_satisfaction response_time_satisfaction communication_satisfaction
           resolved what_liked_note what_improve_note]
      )
    end
end
