module ProjektAdminActions
  extend ActiveSupport::Concern
  include MapLocationAttributes
  include Translatable
  include ImageAttributes

  included do
    alias_method :namespace_mappable_path, :namespace_projekt_path
    helper_method :namespace_projekt_path, :namespace_mappable_path

    before_action :find_projekt, except: %i[index create]
    before_action :process_tags, only: [:update]
  end

  def edit
    @namespace = params[:controller].split("/").first.to_sym

    authorize!(:edit, @projekt)

    @individual_groups = IndividualGroup.hard.visible

    all_settings = ProjektSetting.where(projekt: @projekt).group_by(&:type)
    all_projekt_features = all_settings["projekt_feature"].group_by(&:projekt_feature_type)
    @projekt_features_main = editable_settings(all_projekt_features["main"])
    @projekt_features_general = editable_settings(all_projekt_features["general"])
    @projekt_features_sidebar = editable_settings(all_projekt_features["sidebar"])
    all_projekt_options = all_settings["projekt_option"].group_by(&:projekt_feature_type)
    @projekt_options_general = editable_settings(all_projekt_options["general"])

    @default_footer_tab_setting = ProjektSetting.find_by(
      projekt: @projekt,
      key: "projekt_custom_feature.default_footer_tab"
    )

    ProjektManager.all.map { |pm| pm.projekt_manager_assignments.find_or_create_by!(projekt: @projekt) }
    @projekt_manager_assignments = @projekt.projekt_manager_assignments

    if @projekt.map_location.nil?
      @projekt.send(:copy_map_settings)
      @projekt.reload
    end

    render "custom/admin/projekts/edit"
  end

  def update
    authorize!(:update, @projekt)

    if @projekt.update(projekt_params)
      respond_to do |f|
        f.html do
          redirect_to namespace_projekt_path(action: "edit", anchor: params[:tab]),
            notice: t("custom.admin.projekts.edit.flash.update_notice")
        end
        f.json do
          render json: { projekt: @projekt.serialize, status: { message: "Projekt updated" }}
        end
      end
    else
      respond_to do |f|
        f.html do
          redirect_to namespace_projekt_path(action: "edit"),
            alert: @projekt.errors.messages.values.flatten.join("; ")
        end
        f.json do
          render json: { message: "Error updating projekt" }
        end
      end
    end
  end

  def update_map
    map_location = @projekt.map_location || @projekt.build_map_location

    authorize!(:update_map, map_location)

    map_location.update!(map_location_params)

    redirect_to namespace_projekt_path(action: "edit", anchor: "tab-projekt-map"),
      notice: t("admin.settings.index.map.flash.update")
  end

  def update_standard_phase
    @projekt.reload
    @default_footer_tab_setting = ProjektSetting.find_by(
      projekt: @projekt,
      key: "projekt_custom_feature.default_footer_tab"
    ).reload

    authorize!(:update_standard_phase, @default_footer_tab_setting)

    if @default_footer_tab_setting.present?
      @default_footer_tab_setting.update!(value: params[:default_footer_tab][:id])
    end

    respond_to do |format|
      format.js
    end
  end

  def notify_reviewers
    @projekt = Projekt.find(params[:id])

    authorize!(:edit, @projekt)

    NotificationServices::NewProjektNotifier.call(@projekt)

    respond_to do |format|
      format.html do
        redirect_to page_path(@projekt.page.slug),
                    notice: "Benachrichtigung erfolgreich gesendet"
      end
      format.json { render json: { success: true, message: "Benachrichtigung erfolgreich gesendet" } }
    end
  end

  def toggle_hide_content_background
    authorize!(:edit, @projekt)

    @projekt.update!(show_content_background: !@projekt.show_content_background)

    render json: { show_content_background: @projekt.show_content_background }
  end

  private

    # A setting promoted to a `projekts` column is edited on /adm instead; its
    # row is kept only as a backup, so hide it here. Switching
    # Projekt::USE_SETTING_COLUMNS back to false brings these rows back.
    def editable_settings(settings)
      Array(settings).reject { |setting| Projekt.setting_read_from_column?(setting.key) }
    end

    def projekt_params
      attributes = [
        :name, :parent_id, :total_duration_start, :total_duration_end,
        :show_start_date_in_frontend, :show_end_date_in_frontend,
        :geozone_affiliated, :tag_list, :related_sdg_list, :landing_page_id, geozone_affiliation_ids: [], registered_address_district_affiliation_ids: [], sdg_goal_ids: [],
        individual_group_value_ids: [],
        map_location_attributes: map_location_attributes,
        image_attributes: image_attributes,
        projekt_notifications: [:title, :body],
        project_events: [:id, :title, :location, :datetime, :weblink],
        projekt_manager_assignments_attributes: [:id, :projekt_manager_id, :projekt_id, permissions: []]
      ]
      params.require(:projekt).permit(attributes, translation_params(Projekt))
    end

    def process_tags
      if params[:projekt].present?
        params[:projekt][:tag_list] = (params[:projekt][:tag_list_predefined] || @projekt.tag_list.join(","))
        params[:projekt].delete(:tag_list_predefined)
      end
    end

    def map_location_params
      params.require(:projekt)
            .require(:map_location_attributes)
            .permit(map_location_attributes)
    end

    def find_projekt
      @projekt = Projekt.find(params[:id])
    end

    # path helpers

    def namespace_projekt_path(action: "update", anchor: nil)
      url_for(controller: params[:controller], action: action, anchor: anchor, only_path: true)
    end
end
