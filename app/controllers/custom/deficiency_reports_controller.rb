class DeficiencyReportsController < ApplicationController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes
  include DeficiencyReportsHelper
  include Search

  before_action :authenticate_user!, except: [:index, :show, :json_data]
  before_action :load_categories
  before_action :set_view, only: :index
  before_action :destroy_map_location_association, only: :update
  load_and_authorize_resource

  has_orders ->(c) { DeficiencyReport.deficiency_report_orders }, only: :index
  has_orders %w[newest most_voted oldest], only: :show

  helper_method :resource_model, :resource_name

  def index
    @deficiency_report_count = @deficiency_reports.count

    @areas = DeficiencyReport::Area.where(id: @deficiency_reports.pluck(:deficiency_report_area_id).uniq).order(created_at: :asc)
    @selected_area = DeficiencyReport::Area.find_by(id: params[:dr_area]) if params[:dr_area].present?
    @map_location = @selected_area&.map_location
    @deficiency_reports = @deficiency_reports.where(deficiency_report_area_id: @selected_area&.id) if @selected_area.present?

    @deficiency_reports = @deficiency_reports.send("sort_by_#{@current_order}").page(params[:page])

    @categories = DeficiencyReport::Category.all.order(created_at: :asc)
    @selected_categories_ids = (params[:dr_categories] || '').split(',')

    @statuses = DeficiencyReport::Status.all.order(given_order: :asc)
    @selected_status_id = (params[:dr_status] || '').split(',').first

    @selected_officer = params[:dr_officer]

    @deficiency_reports = @deficiency_reports.search(@search_terms) if @search_terms.present?

    filter_by_categories if @selected_categories_ids.present?
    filter_by_selected_status if @selected_status_id.present?
    filter_by_selected_officer if @selected_officer.present?
    filter_by_my_posts

    @deficiency_reports_coordinates = all_deficiency_report_map_locations(@deficiency_reports)

    set_deficiency_report_votes(@deficiency_reports)

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end

      format.csv do
        formated_time = Time.current.strftime("%d-%m-%Y-%H-%M-%S")
        send_data CsvServices::DeficiencyReportsExporter.call(@deficiency_reports),
          filename: "deficiency_reports-#{formated_time}.csv"
      end
    end
  end

  def show
    @commentable = @deficiency_report
    @comment_tree = CommentTree.new(@deficiency_report, params[:page], @current_order)
    set_comment_flags(@comment_tree.comments)
    set_deficiency_report_votes(@deficiency_reports)

    if Setting.new_design_enabled?
      render :show_new
    else
      render :show
    end
  end

  def new
    @deficiency_report = DeficiencyReport.new
  end

  def create
    status = DeficiencyReport::Status.first

    if deficiency_report_params["image_attributes"]["cached_attachment"].blank?
      filtered_deficiency_report_params = deficiency_report_params.except("image_attributes")
    else
      filtered_deficiency_report_params = deficiency_report_params
    end

    @deficiency_report = DeficiencyReport.new(filtered_deficiency_report_params.merge(author: current_user, status: status))
    @deficiency_report.responsible = @deficiency_report.get_default_responsible

    if @deficiency_report.save
      NotificationServices::NewDeficiencyReportNotifier.new(@deficiency_report.id).call
      notify_responsible(@deficiency_report)
      redirect_to deficiency_report_path(@deficiency_report)
    else
      render :new
    end
  end

  def destroy
    @deficiency_report.destroy

    redirect_to deficiency_reports_path
  end

  def vote
    @deficiency_report.register_vote(current_user, params[:value])
    set_deficiency_report_votes(@deficiency_report)
  end

  def suggest
    @limit = 5
    @resources = @search_terms.present? ? DeficiencyReport.admin_accepted.search(@search_terms) : nil
  end

  def notify_officer_about_new_comments
    return unless @deficiency_report.officer.present?

    enable = ["1", "true"].include?(deficiency_report_params[:notify_officer_about_new_comments])
    datetime = enable ? Time.current : nil

    if @deficiency_report.update!(
      notify_officer_about_new_comments: deficiency_report_params[:notify_officer_about_new_comments],
      notified_officer_about_new_comments_datetime: datetime
    ) && enable && @deficiency_report.comments.any?
      last_comment_date = @deficiency_report.comments.last.created_at
      last_comment_date_expanded = last_comment_date - 5.minutes
      new_comments = @deficiency_report.comments.created_after_date(last_comment_date_expanded)

      if new_comments.any?
        NotificationServiceMailer.new_comments_for_deficiency_report(
          @deficiency_report,
          last_comment_date_expanded,
          initial: true
        ).deliver_now
      end
    end

    head :ok
  end

  private

  def filter_by_my_posts
    return unless params[:my_posts_filter] == 'true'

    @deficiency_reports = @deficiency_reports.by_author(current_user&.id)
  end

  def load_categories
    @categories = Tag.category.order(:name)
  end

  def deficiency_report_params
    attributes = [:video_url, :on_behalf_of,
                  :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general, :resource_terms,
                  :deficiency_report_category_id,
                  :deficiency_report_area_id,
                  :notify_officer_about_new_comments,
                  map_location_attributes: map_location_attributes,
                  documents_attributes: document_attributes,
                  image_attributes: image_attributes]
    params.require(:deficiency_report).permit(attributes, translation_params(DeficiencyReport))
  end


  def destroy_map_location_association
    map_location = params[:deficiency_report][:map_location_attributes]
    if map_location && (map_location[:longitude] && map_location[:latitude]).blank? && !map_location[:id].blank?
      MapLocation.destroy(map_location[:id])
    end
  end

  def filter_by_categories
    @deficiency_reports = @deficiency_reports.where(category: @selected_categories_ids)
  end

  def filter_by_selected_status
    @deficiency_reports = @deficiency_reports.where(status: @selected_status_id)
  end

  def filter_by_selected_officer
    if @selected_officer == 'current_user'
      @deficiency_reports = @deficiency_reports.joins(:officer).where(deficiency_report_officers: { user_id: current_user.id })
    else
      @deficiency_reports
    end
  end

  def set_view
    @view = (params[:view] == "minimal") ? "minimal" : "default"
  end

  def resource_name
    "deficiency_report"
    #@resource_name ||= resource_model.to_s.downcase
  end

  def resource_model
    DeficiencyReport
  end

  def notify_responsible(dr)
    return if dr.responsible.blank?

    if dr.responsible.is_a?(DeficiencyReport::Officer)
      DeficiencyReportMailer.notify_officer(dr, dr.responsible).deliver_later
    elsif dr.responsible.is_a?(DeficiencyReport::OfficerGroup)
      dr.responsible.officers.each do |officer|
        DeficiencyReportMailer.notify_officer(dr, officer).deliver_later
      end
    end
  end
end
