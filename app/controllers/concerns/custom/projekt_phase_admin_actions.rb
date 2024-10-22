module ProjektPhaseAdminActions
  extend ActiveSupport::Concern
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include ProjektPhaseControllerUtils

  included do
    alias_method :namespace_mappable_path, :namespace_projekt_phase_path

    before_action :set_projekt_phase, :authorize_nav_bar_action, except: [
      :create, :order_phases, :frame_phases_restrictions,
      :frame_new_phase_selector
    ]
    before_action :set_namespace
    helper_method :namespace_projekt_phase_path, :namespace_mappable_path
  end

  def create
    @projekt = Projekt.find(params[:projekt_id])
    @projekt_phase = ProjektPhase.new(projekt_phase_params.merge(active: true))

    authorize!(:create, @projekt_phase)

    @projekt_phase.save!

    if embedded? && frame_session_from_authorized_source?
      redirect_to polymorphic_path([@namespace, @projekt_phase], action: :duration)
    else
      redirect_to polymorphic_path([@namespace, @projekt], action: :edit, anchor: "tab-projekt-phases"),
        notice: t("custom.admin.projekt_phases.notice.created")
    end
  end

  def update
    authorize!(:create, @projekt_phase)

    if @projekt_phase.update(projekt_phase_params)

      if params[:action_name].present?
        redirect_to(
          namespace_projekt_phase_path(action: params[:action_name]),
          notice: t("custom.admin.projekt_phases.notice.updated")
        )
      elsif embedded?
        redirect_to(
          @projekt_phase.projekt.frame_url,
          notice: t("custom.admin.projekt_phases.notice.updated")
        )
      end
    end
  end

  def destroy
    authorize!(:destroy, @projekt_phase)

    if @projekt_phase.safe_to_destroy?
      @projekt_phase.destroy!
      redirect_to polymorphic_path([@namespace, @projekt], action: :edit, anchor: "tab-projekt-phases"),
        notice: t("custom.admin.projekt_phases.notice.destroyed")

    else
      redirect_to polymorphic_path([@namespace, @projekt], action: :edit, anchor: "tab-projekt-phases"),
        notice: t("custom.admin.projekt_phases.notice.not_destroyed")

    end
  end

  def order_phases
    @projekt = Projekt.find(params[:projekt_id])
    authorize!(:order_phases, @projekt)

    @projekt.projekt_phases.order_phases(params[:ordered_list])
    head :ok
  end

  def toggle_active_status
    authorize!(:toggle_active_status, @projekt_phase)

    status_value = params[:projekt][:phase_attributes][:active]
    @projekt_phase.update!(active: status_value)
  end

  def duration
    authorize!(:duration, @projekt_phase)

    render "custom/admin/projekt_phases/duration"
  end

  def naming
    authorize!(:naming, @projekt_phase)

    render "custom/admin/projekt_phases/naming"
  end

  def restrictions
    authorize!(:restrictions, @projekt_phase)

    @registered_address_groupings = RegisteredAddress::Grouping.all
    @individual_groups = IndividualGroup.visible

    render "custom/admin/projekt_phases/restrictions"
  end

  def settings
    authorize!(:settings, @projekt_phase)

    if params[:category].present?
      projekt_phase_features, projekt_phase_options =
        get_all_settings_for_phase_and_category(
          @projekt_phase, params[:category]
        )
      @projekt_phase_features = { params[:category] => projekt_phase_features }
      @projekt_phase_options = { params[:category] => projekt_phase_options }
    else
      projekt_phase_features, projekt_phase_options =
        get_all_settings_for_phase_and_category(
          @projekt_phase, :base
        )

      @projekt_phase_features = projekt_phase_features&.group_by(&:band) || []
      @projekt_phase_options = projekt_phase_options&.group_by(&:band) || []
    end

    @projekt_phase_features.each { |_, v| v.delete_if { |a| a.key.in? @projekt_phase.settings_in_tabs.keys }} if @projekt_phase_features.presence&.values&.compact.present?
    @projekt_phase_options.each { |_, v| v.delete_if { |a| a.key.in? @projekt_phase.settings_in_tabs.keys }} if @projekt_phase_options.presence&.values&.compact.present?

    render "custom/admin/projekt_phases/settings"
  end

  def get_all_settings_for_phase_and_category(projekt_phase, category)
    proposal_setting_key_ordered = ProjektPhaseSetting.defaults[projekt_phase.class.name][category.to_sym].keys

    projekt_phase_settings_by_key = projekt_phase.settings.each_with_object({}) do |item, result|
      result[item.key] = item
    end

    setting_ordered = []
    proposal_setting_key_ordered.each do |setting_key|
      setting = projekt_phase_settings_by_key[setting_key.to_s]
      setting_ordered.push(setting)
    end

    all_settings = setting_ordered.group_by(&:kind)

    projekt_phase_features = all_settings["feature"]
    projekt_phase_options = all_settings["option"]

    [projekt_phase_features, projekt_phase_options]
  end

  def projekt_labels
    authorize!(:projekt_labels, @projekt_phase)

    @projekt_labels = @projekt_phase.projekt_labels

    render "custom/admin/projekt_phases/projekt_labels"
  end

  def sentiments
    authorize!(:sentiments, @projekt_phase)
    @sentiments = @projekt_phase.sentiments

    render "custom/admin/projekt_phases/sentiments"
  end

  def map
    authorize!(:map, @projekt_phase)

    @projekt_phase.create_map_location unless @projekt_phase.map_location.present?
    @map_location = @projekt_phase.map_location

    render "custom/admin/projekt_phases/map"
  end

  def update_map
    map_location = MapLocation.find_by(projekt_phase_id: params[:id])

    authorize!(:update_map, map_location)

    map_location.update!(map_location_params)

    redirect_to namespace_projekt_phase_path(action: "map"),
      notice: t("admin.settings.index.map.flash.update")
  end

  def copy_map_settings_from_projekt
    authorize!(:copy_map_settings_from_projekt, @projekt_phase)

    unless @projekt_phase.map_location.latitude == @projekt_phase.projekt.map_location.latitude &&
           @projekt_phase.map_location.longitude == @projekt_phase.projekt.map_location.longitude
      @projekt_phase.map_location = @projekt_phase.projekt.map_location.dup
    end

    @projekt_phase.projekt.map_layers.each do |map_layer|
      @projekt_phase.map_layers << map_layer.dup unless @projekt_phase.map_layers.any? { |ml| ml.name == map_layer.name }
    end

    redirect_to namespace_projekt_phase_path(action: "map"),
      notice: t("admin.settings.index.map.flash.update")
  end

  def age_ranges_for_stats
    authorize!(:age_ranges_for_stats, @projekt_phase)
    @age_ranges = AgeRange.for_stats

    render "custom/admin/projekt_phases/age_ranges_for_stats"
  end

  def projekt_questions
    authorize!(:projekt_questions, @projekt_phase)
    @projekt_questions = @projekt_phase.questions

    render "custom/admin/projekt_phases/projekt_questions"
  end

  def projekt_livestreams
    authorize!(:projekt_livestreams, @projekt_phase)
    @projekt_livestream = ProjektLivestream.new
    @projekt_livestreams = @projekt_phase.projekt_livestreams

    render "custom/admin/projekt_phases/projekt_livestreams"
  end

  def projekt_events
    authorize!(:projekt_events, @projekt_phase)
    @projekt_event = ProjektEvent.new
    @projekt_events = @projekt_phase.projekt_events.order(datetime: :desc)

    render "custom/admin/projekt_phases/projekt_events"
  end

  def milestones
    authorize!(:milestones, @projekt_phase)
    render "custom/admin/projekt_phases/milestones"
  end

  def progress_bars
    authorize!(:progress_bars, @projekt_phase)
    render "custom/admin/projekt_phases/progress_bars"
  end

  def projekt_notifications
    authorize!(:projekt_notifications, @projekt_phase)
    @projekt_notification = ProjektNotification.new
    @projekt_notifications = @projekt_phase.projekt_notifications

    render "custom/admin/projekt_phases/projekt_notifications"
  end

  def projekt_arguments
    authorize!(:projekt_arguments, @projekt_phase)
    @projekt_argument = ProjektArgument.new
    @projekt_arguments_pro = @projekt_phase.projekt_arguments.pro
    @projekt_arguments_cons = @projekt_phase.projekt_arguments.cons

    render "custom/admin/projekt_phases/projekt_arguments"
  end

  def formular
    @formular = @projekt_phase.formular
    @formular_fields_primary = @formular.formular_fields.primary.each(&:set_custom_attributes)
    @formular_fields_follow_up = @formular.formular_fields.follow_up.each(&:set_custom_attributes)
    authorize!(:formular, @projekt_phase)
    render "custom/admin/projekt_phases/formular"
  end

  def formular_answers
    authorize!(:formular, @projekt_phase)

    @formular = @projekt_phase.formular
    @formular_fields = @formular.formular_fields
    @formular_answers = @formular.formular_answers
    @formular_follow_up_letters = @formular.formular_follow_up_letters
    @image_flag = @formular_answers.any? { |fa| fa.formular_answer_images.present? }
    @document_flag = @formular_answers.any? { |fa| fa.formular_answer_documents.present? }

    respond_to do |format|
      format.html { render "custom/admin/projekt_phases/formular_answers" }
      format.csv do
        send_data CsvServices::FormularAnswersExporter.call(@formular),
          filename: "formular_answers-#{@formular.id}-#{Time.zone.today}.csv"
      end
    end
  end

  def poll_questions
    authorize!(:poll_questions, @projekt_phase)
    @poll = @projekt_phase.poll
    @questions = @poll.questions

    render "custom/admin/projekt_phases/poll_questions"
  end

  def poll_booth_assignments
    authorize!(:poll_booth_assignments, @projekt_phase)
    @poll = @projekt_phase.poll
    @booth_assignments = @poll.booth_assignments.includes(:booth).order("poll_booths.name")
                              .page(params[:page]).per(50)

    render "custom/admin/projekt_phases/poll_booth_assignments"
  end

  def poll_officer_assignments
    authorize!(:poll_officer_assignments, @projekt_phase)
    @poll = @projekt_phase.poll
    @officers = ::Poll::Officer.
                  includes(:user).
                  order("users.username").
                  where(
                    id: @poll.officer_assignments.select(:officer_id).distinct.map(&:officer_id)
                  ).page(params[:page]).per(50)

    render "custom/admin/projekt_phases/poll_officer_assignments"
  end

  def poll_recounts
    authorize!(:poll_recounts, @projekt_phase)
    @poll = @projekt_phase.poll
    @stats = Poll::Stats.new(@poll)
    @booth_assignments = @poll.booth_assignments.
                              includes(:booth, :recounts, :voters).
                              order("poll_booths.name").
                              page(params[:page]).per(50)

    render "custom/admin/projekt_phases/poll_recounts"
  end

  def poll_results
    authorize!(:poll_results, @projekt_phase)
    @poll = @projekt_phase.poll
    @partial_results = @poll.partial_results

    render "custom/admin/projekt_phases/poll_results"
  end

  def budget_edit
    authorize!(:budget_edit, @projekt_phase)
    @budget = @projekt_phase.budget

    render "custom/admin/projekt_phases/budget_edit"
  end

  def budget_investments
    authorize!(:budget_investments, @projekt_phase)
    @budget = @projekt_phase.budget

    @investments = @budget.investments
                          .scoped_filter(params.merge(budget_id: @budget.id), "all")
                          .order_filter(params.merge(budget_id: @budget.id))
    @investments = Kaminari.paginate_array(@investments) if @investments.is_a?(Array)
    @investments = @investments.page(params[:page]) unless request.format.csv?

    render "custom/admin/projekt_phases/budget_investments"
  end

  def budget_phases
    authorize!(:budget_phases, @projekt_phase)
    @budget = @projekt_phase.budget

    render "custom/admin/projekt_phases/budget_phases"
  end

  def legislation_process_draft_versions
    authorize!(:legislation_process_draft_versions, @projekt_phase)
    @process = @projekt_phase.legislation_process

    render "custom/admin/projekt_phases/legislation_process_draft_versions"
  end

  def frame_new_phase_selector
    @projekt = Projekt.find(params[:projekt_id])

    authorize!(:edit, @projekt)

    render
  end

  # def frame_phases_restrictions
  #   @projekt = Projekt.find(params[:projekt_id])
  #   authorize!(:edit, @projekt)
  #
  #   render "custom/admin/projekt_phases/frame_phases_restrictions"
  # end
  #
  # def frame_phase_edit
  #   @projekt = Projekt.find(params[:projekt_id])
  #   authorize!(:edit, @projekt)
  #
  #   render "custom/admin/projekt_phases/frame_phases_restrictions"
  # end

  private

    def projekt_phase_params
      if params[:projekt_phase][:registered_address_grouping_restrictions]
        filter_empty_registered_address_grouping_restrictions
      end

      params.require(:projekt_phase).permit(
        translation_params(ProjektPhase),
        :projekt_id, :type,
        :active, :start_date, :end_date,
        :user_status, :age_range_id,
        :geozone_restricted, :registered_address_grouping_restriction,
        geozone_restriction_ids: [], registered_address_street_ids: [],
        individual_group_value_ids: [],
        age_ranges_for_stat_ids: [],
        settings_attributes: [:id, :value],
        polls_attributes: [:id, :show_open_answer_author_name, { image_attributes: image_attributes }, translation_params(Poll)],
        registered_address_grouping_restrictions: registered_address_grouping_restrictions_params_to_permit)
    end

    def map_location_params
      if params[:map_location]
        params.require(:map_location).permit(map_location_attributes)
      else
        params.permit(map_location_attributes)
      end
    end

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:id])
      @projekt = @projekt_phase.projekt
    end

    def set_namespace
      @namespace = params[:controller].split("/").first.to_sym
    end

    def registered_address_grouping_restrictions_params_to_permit
      keys_hash = RegisteredAddress::Grouping.all
        .pluck(:key).each_with_object({}) do |key, hash|
          hash[key.to_sym] = []
        end
      keys_hash
    end

    def filter_empty_registered_address_grouping_restrictions
      grouping_restrictions = params[:projekt_phase][:registered_address_grouping_restrictions]
      return if grouping_restrictions.blank?

      filtered_grouping_restrictions = grouping_restrictions
        .reject { |_, v| v == [""] }
        .as_json
        .each { |_, v| v.reject!(&:blank?) }

      params[:projekt_phase][:registered_address_grouping_restrictions] = filtered_grouping_restrictions
    end

    def authorize_nav_bar_action
      possible_nab_bar_actions = @projekt_phase.projekt.projekt_phases.map(&:admin_nav_bar_items).flatten.uniq
      return unless action_name.in?(possible_nab_bar_actions)

      unless action_name.in?(@projekt_phase.admin_nav_bar_items) || action_name == "settings"
        redirect_to namespace_projekt_phase_path(action: @projekt_phase.admin_nav_bar_items.first)
      end
    end

    # path helpers

    def namespace_projekt_phase_path(action: "update", url_params: {})
      url_for(controller: params[:controller], action: action, params: url_params, only_path: true)
    end
end
