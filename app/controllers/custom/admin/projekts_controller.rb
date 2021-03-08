class Admin::ProjektsController < Admin::BaseController
  before_action :find_projekt, only: [:update, :destroy]

  def index
    @projekts = Projekt.all.page(params[:page])
    @projekt = Projekt.new
  end

  def update
    if @projekt.update_attributes(projekt_params)
      redirect_to admin_projekts_path
    else
      render action: :edit
    end
  end

  def create
    Projekt.find_or_create_by!(name: projekt_params["name"])
    redirect_to admin_projekts_path
  end

  def destroy
    @projekt.destroy!
    redirect_to admin_projekts_path
  end

  private

    def projekt_params
      params.require(:projekt).permit(:name, :parent_id)
    end

    def find_projekt
      @projekt = Projekt.find(params[:id])
    end
end
