module Adm
  class AgeRangesController < Adm::BaseController
    def index
      authorize [:adm, :age_range]
      @current_filter = %w[for_restrictions for_stats].include?(params[:filter]) ? params[:filter] : "for_restrictions"
      scope = policy_scope([:adm, AgeRange]).send(@current_filter)
      @pagy, @age_ranges = pagy(scope.order(:order))

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.age_ranges") }
      ]
    end

    def new
      @age_range = AgeRange.new
      authorize [:adm, @age_range]

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.age_ranges"), url: adm_age_ranges_path },
        { name: t(".title") }
      ]
    end

    def create
      @age_range = AgeRange.new(age_range_params)
      authorize [:adm, @age_range]

      if @age_range.save
        redirect_to adm_age_ranges_path, notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @age_range = AgeRange.find(params[:id])
      authorize [:adm, @age_range]

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.age_ranges"), url: adm_age_ranges_path },
        { name: t(".title") }
      ]
    end

    def update
      @age_range = AgeRange.find(params[:id])
      authorize [:adm, @age_range]

      if @age_range.update(age_range_params)
        redirect_to adm_age_ranges_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @age_range = AgeRange.find(params[:id])
      authorize [:adm, @age_range]

      @age_range.destroy!
      redirect_to adm_age_ranges_path, notice: t(".success")
    end

    def reorder
      authorize [:adm, :age_range], :update?
      ordered_ids = params[:tree].map { |item| item[:id] }
      AgeRange.order_records(ordered_ids)
      head :ok
    end

    private

      def age_range_params
        params.require(:age_range).permit(:order, :min_age, :max_age, :only_for_stats, :name)
      end
  end
end
