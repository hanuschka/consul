module Adm
  module SiteCustomization
    class ImagesController < Adm::BaseController
      def update
        authorize [:adm, Setting], :update?

        @image = ::SiteCustomization::Image.find(params[:id])
        @kind = params[:kind].to_sym

        @image.update(image_params) #rubocop:disable Rails/SaveBang
      end

      private

        def image_params
          params.require(:site_customization_image).permit(:image)
        end
    end
  end
end
