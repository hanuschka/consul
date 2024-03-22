class Admin::AgeRangesController < Admin::BaseController
  include Translatable

  has_filters %w[for_restrictions for_stats]

  before_action :set_age_range, only: %i[edit update destroy]

  def index
    @age_ranges = AgeRange.send(@current_filter)
  end

  def new
    @age_range = AgeRange.new
  end

  def create
    @age_range = AgeRange.new(age_range_params)
    return_filter = @age_range.only_for_stats? ? "for_stats" : "for_restrictions"

    if @age_range.save
      redirect_to admin_age_ranges_path(filter: return_filter)
    end
  end

  def edit
  end

  def update
    if @age_range.update(age_range_params)
      redirect_to admin_age_ranges_path
    end
  end

  def destroy
    @age_range.destroy!

    redirect_to admin_age_ranges_path
  end

  def order_records
    AgeRange.order_records(params[:ordered_list])
    head :ok
  end

  private

    def set_age_range
      @age_range = AgeRange.find(params[:id])
    end

    def age_range_params
      params.require(:age_range).permit(
        :order, :min_age, :max_age, :only_for_stats,
        translation_params(AgeRange)
      )
    end
end
