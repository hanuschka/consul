class Admin::ProjektArgumentsController < Admin::BaseController
  include ImageAttributes

  before_action :set_projekt
  before_action :set_namespace, except: :destroy

  def create
    @projekt_argument = ProjektArgument.new(projekt_argument_params)
    @projekt_argument.projekt = @projekt

    authorize! :create, @projekt_argument if @namespace == "projekt_management"

    @projekt_argument.save!
    redirect_to redirect_path(@projekt), notice: t("admin.settings.flash.updated")
  end

  def update
    @projekt_argument = ProjektArgument.find_by(id: params[:id])

    authorize! :update, @projekt_argument if @namespace == "projekt_management"

    @projekt_argument.update!(projekt_argument_params)
    redirect_to redirect_path(@projekt), notice: t("admin.settings.flash.updated")
  end

  def destroy
    @projekt_argument = ProjektArgument.find_by(id: params[:id])
    @namespace = params[:namespace]

    authorize! :destroy, @projekt_argument if @namespace == "projekt_management"

    @projekt_argument.destroy!
    redirect_to redirect_path(@projekt)
  end

  private

    def projekt_argument_params
      params.require(:projekt_argument).permit(:name, :party, :pro, :position,
                                               :note, image_attributes: image_attributes)
    end

    def set_projekt
      @projekt = Projekt.find(params[:projekt_id])
    end

    def set_namespace
      @namespace = params[:projekt_argument][:namespace]
    end

    def redirect_path(projekt)
      if @namespace == "projekt_management"
        edit_projekt_management_projekt_path(projekt) + "#tab-projekt-arguments"
      else
        edit_admin_projekt_path(projekt) + "#tab-projekt-arguments"
      end
    end
end
