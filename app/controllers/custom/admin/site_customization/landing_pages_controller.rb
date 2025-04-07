class Admin::SiteCustomization::LandingPagesController < Admin::SiteCustomization::BaseController
  include Translatable
  include ImageAttributes

  before_action :find_page, only: [:edit, :update, :edit_content_cards]

  def index
    @pages = ::SiteCustomization::Page.landing.order(:landing_nav_position).page(params[:page])

    render "admin/site_customization/pages/index"
  end

  def edit
    authorize!(:udpate, @page)
    find_or_create_content_cards(@page)

    render "admin/site_customization/pages/edit"
  end

  def new
    @page = ::SiteCustomization::Page.new
    authorize!(:update, @page)
    @page.landing = true

    render "admin/site_customization/pages/new"
  end

  def create
    @page = ::SiteCustomization::Page.new(page_params)

    if @page.save
      notice = t("admin.site_customization.pages.create.notice")

      find_or_create_content_cards(@page)

      redirect_to edit_content_cards_admin_site_customization_landing_page_path(@page), notice: notice
    else
      flash.now[:error] = t("admin.site_customization.pages.create.error")
      render "admin/site_customization/pages/new"
    end
  end

  def update
    authorize!(:udpate, @page)

    optimize_mobile_header_image

    if @page.update(page_params)
      notice = t("admin.site_customization.pages.update.notice")

      redirect_to admin_site_customization_landing_pages_path, notice: notice
    else
      find_or_create_content_cards(@page)

      flash.now[:error] = t("admin.site_customization.pages.update.error")
      render "admin/site_customization/pages/edit"
    end
  end

  def update_order
    # authorize!(:udpate, ::SiteCustomization::Page)

    ::SiteCustomization::Page.order_landing_pages(params[:ordered_list])
    head :ok
  end

  def edit_content_cards
    authorize!(:udpate, @page)
    find_or_create_content_cards(@page)

    render
  end

  private

    def find_page
      @page = ::SiteCustomization::Page.landing.find(params[:id])
    end

    def find_or_create_content_cards(page)
      @content_cards =
        SiteCustomization::ContentCard
        .get_or_create_for_landing_page(
          page.id
        )
    end

    def page_params
      attributes = [
        :slug, :landing, :more_info_flag,
        :print_content_flag, :status,
        :landing_show_in_top_nav,
        :landing_hide_all_top_nav_links,
        :landing_hide_title_and_subtitle,
        :landing_show_projekts_overview,
        :landing_site_logo_not_clickable,
        :landing_mobile_header_image,
        image_attributes: image_attributes
      ]

      params.require(:site_customization_page).permit(*attributes,
        translation_params(SiteCustomization::Page)
      )
    end

    def optimize_mobile_header_image
      if page_params[:landing_mobile_header_image].present?
        new_image =
          ImageProcessing::MiniMagick
            .source(page_params[:landing_mobile_header_image])
            .convert('jpg')
            .resize_to_fit(
              780,
              550
            )
            .saver(quality: 80, interlace: 'Line')
            .call

        page_params[:landing_mobile_header_image] = new_image
      end
    end
end
