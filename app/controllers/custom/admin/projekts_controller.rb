class Admin::ProjektsController < Admin::BaseController
  include ProjektAdminActions

  def index
    @projekts = Projekt.top_level.regular

    @new_projekt = Projekt.new
    @overview_page_projekt = Projekt.overview_page

    @projekts_settings = Setting.all.group_by(&:type)["projekts"]

    @projekts_overview_page_navigation_settings = Setting.all.select do |setting|
      setting.key.start_with?("extended_feature.projekts_overview_page_navigation")
    end

    @projekts_overview_page_footer_settings = Setting.all.select do |setting|
      setting.key.start_with?("extended_feature.projekts_overview_page_footer")
    end

    @overview_page_special_projekt = Projekt.unscoped.find_by(
      special: true,
      special_name: "projekt_overview_page"
    )

    @map_configuration_settings = Setting.all.group_by(&:type)["map"]
    @geozones = Geozone.all.order(Arel.sql("LOWER(name)"))

    @projekts = @projekts.page(params[:page]).per(10)
  end

  def show
    redirect_to edit_admin_projekt_path
  end

  def quick_update
    @projekt.update!(projekt_params)
    Projekt.ensure_order_integrity

    redirect_to admin_projekts_path(page: params[:page])
  end

  def create
    @projekt = Projekt.new(projekt_params)

    if @projekt.save
      redirect_to admin_projekts_path
    else
      @projekts = Projekt.top_level.page(params[:page])
      render :index
    end
  end

  def destroy
    @projekt.children.each do |child|
      child.update(parent: nil)
    end
    @projekt.debates.unscope(where: :hidden_at).each do |debate|
      debate.update(projekt_id: nil)
    end
    @projekt.proposals.unscope(where: :hidden_at).each do |proposal|
      proposal.update(projekt_id: nil)
    end
    @projekt.polls.unscope(where: :hidden_at).each do |poll|
      poll.update(projekt_id: nil)
    end
    @projekt.destroy!
    redirect_to admin_projekts_path
  end

  def order_up
    @projekt = Projekt.find(params[:id])
    @projekt.order_up
    redirect_to admin_projekts_path
  end

  def order_down
    @projekt = Projekt.find(params[:id])
    @projekt.order_down
    redirect_to admin_projekts_path
  end
end
