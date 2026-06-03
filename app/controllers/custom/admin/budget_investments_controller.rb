class Admin::BudgetInvestmentsController < Admin::BaseController
  include AdminActions::BudgetInvestments

  EXPORT_SYNC_RECORD_LIMIT = 5000

  def index
    authorize!(:create, @budget) if @namespace == :projekt_management

    load_tags
    respond_to do |format|
      format.html { render "admin/budget_investments/index" }
      format.js { render "admin/budget_investments/index" }
      format.csv do
        send_data Budget::Investment::Exporter.new(@investments).to_csv,
                  filename: "budget_investments.csv"
      end
      format.geojson { send_geojson_export }
    end
  end

  private

    def send_geojson_export
      scope = @investments.is_a?(ActiveRecord::Relation) ? @investments.limit(nil) : Budget::Investment.where(id: @investments.map(&:id))
      source_filter = params[:source_filter].presence || "all"

      if scope.count > EXPORT_SYNC_RECORD_LIMIT
        redirect_to admin_budget_budget_investments_path(@budget),
                    notice: t("admin.budget_investments.index.export_queued")
        return
      end

      send_data GeoServices::GeoJsonExporter.call(scope, source_filter: source_filter),
                filename: "budget_investments-#{Time.current.to_i}.geojson",
                type: "application/geo+json"
    end
end
