class Admin::DeficiencyReportsController < Admin::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes

  def index
    @deficiency_reports = DeficiencyReport.all.order(id: :desc)

    unless params[:format] == "csv"
      @deficiency_reports = @deficiency_reports.page(params[:page].presence || 0).per(params[:limit].presence || 20)
    end

    respond_to do |format|
      format.html
      format.csv do
        send_data DeficiencyReport::CsvExporter.new(@deficiency_reports).to_csv,
          filename: "deficiency_reports.csv"
      end
    end
  end

  def show
    @deficiency_report = DeficiencyReport.find(params[:id])
  end

  def edit
    @deficiency_report = DeficiencyReport.find(params[:id])
    @areas = DeficiencyReport::Area.all.order(created_at: :asc)
    @map_coordinates_for_areas = @areas.map do |area|
      [area.id, [area.map_location.latitude, area.map_location.longitude]]
    end.to_h
  end

  def update
    @deficiency_report = DeficiencyReport.find(params[:id])

    if @deficiency_report.update(deficiency_report_params)
      redirect_to admin_deficiency_reports_path, notice: t("custom.admin.deficiency_reports.update.success_notice")
    else
      render :edit
    end
  end

  def destroy
    @deficiency_report = DeficiencyReport.find(params[:id])
    @deficiency_report.destroy!

    redirect_to admin_deficiency_reports_path, notice: t("custom.admin.deficiency_reports.destroy.success_notice")
  end

  def accept
    enabled = ["1", "true"].include?(params[:deficiency_report][:admin_accepted])
    deficiency_report = DeficiencyReport.find(params[:deficiency_report][:id])

    deficiency_report.update!(admin_accepted: enabled)

    head :ok
  end

  private

    def deficiency_report_params
      attributes = [:video_url, :on_behalf_of,
                    :deficiency_report_category_id,
                    :deficiency_report_area_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:deficiency_report).permit(attributes, translation_params(DeficiencyReport))
    end
end
