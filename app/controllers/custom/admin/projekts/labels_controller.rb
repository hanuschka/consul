class Admin::Projekts::LabelsController < Admin::BaseController
  include Translatable
  respond_to :js

  before_action :set_projekt, except: %i[index show destroy]
  before_action :set_projekt_label, only: %i[edit update destroy]

  def new
    @projekt_label = Projekt::Label.new
    authorize! :create, @projekt_label

    render "custom/admin/projekts/edit/projekt_labels/new"
  end

  def create
    @projekt_label = Projekt::Label.new(projekt_label_params)
    @projekt_label.projekt = @projekt
    authorize! :create, @projekt_label

    if @projekt_label.save
      redirect_to edit_admin_projekt_path(@projekt, anchor: "tab-projekt-labels")
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @projekt_label.update(projekt_label_params)
      redirect_to admin_projekt_path(@projekt, anchor: "tab-projekt-labels")
    else
      render :edit
    end
  end

  def destroy
    @projekt_label.destroy!
    redirect_to edit_admin_projekt_path(@projekt, anchor: "tab-projekt-labels"), notice: t("custom.admin.projekt.label.destroy.success")
  end

  private

    def set_projekt
      @projekt = Projekt.find(params[:projekt_id])
    end

    def set_projekt_label
      @projekt_label = Projekt::Label.find(params[:id])
    end

    def projekt_label_params
      params.require(:projekt_label).permit(:color, :icon, :projekt_id, translation_params(Projekt::Label))
    end
end
