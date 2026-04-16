class InternalApi::ProjektsController < InternalApi::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :process_tags, only: [:update]

  skip_authorization_check

  def overview
    current_visible_projekts =
      Projekt
        .activated
        .with_published_custom_page
        .show_in_overview_page
        .regular

    current_visible_projekts
      .where(on_global_overview: false)
      .update_all(on_global_overview: true)

    projekts_on_global_overview =
      Projekt
        .where(on_global_overview: true)
        .includes(:page, :projekt_phases, :map_location)

    render json: {
      projekts: projekts_on_global_overview.map do |projekt|
        Projekts::SerializeForOverview.call(projekt)
      end
    }
  end

end
