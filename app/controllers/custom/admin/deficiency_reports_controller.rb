class Admin::DeficiencyReportsController < Admin::BaseController
  def index
    super

    respond_to do |format|
      format.html
      format.csv do
        send_data DeficiencyReport::CsvExporter.new(@resources).to_csv,
          filename: "deficiency_reports.csv"
      end
    end
  end
end
