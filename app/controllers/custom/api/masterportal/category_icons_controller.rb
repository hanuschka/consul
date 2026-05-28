class Api::Masterportal::CategoryIconsController < ActionController::API
  before_action :authenticate_sync_token!
  before_action :load_category

  def create
    return render_error("invalid_content_type") if !allowed_content_type?
    return render_error("too_large") if !allowed_size?
    return render_error("unsafe_svg") if !safe_svg?

    @category.icon_image.attach(params[:icon])

    head :no_content
  end

  private

    def authenticate_sync_token!
      expected = Rails.application.secrets.masterportal_sync_api_token
      provided = request.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")

      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided)

      head :unauthorized
    end

    def load_category
      @category = ProjektPointOfInterestCategory
                    .joins(:projekt_phase)
                    .where(projekt_phase_id: params[:projekt_phase_id])
                    .where("LOWER(name) = LOWER(?)", params[:category_name])
                    .first

      if @category.nil?
        head :not_found
      end
    end

    def allowed_content_type?
      ProjektPointOfInterestCategory::ALLOWED_ICON_CONTENT_TYPES.include?(params[:icon]&.content_type)
    end

    def allowed_size?
      params[:icon].present? && params[:icon].size <= ProjektPointOfInterestCategory::MAX_ICON_BYTE_SIZE
    end

    def safe_svg?
      return true if params[:icon]&.content_type != "image/svg+xml"

      Masterportal::SvgSanitizer.safe?(params[:icon].tempfile)
    end

    def render_error(code)
      render json: { error: code }, status: :unprocessable_entity
    end
end
