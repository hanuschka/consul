module Adm
  module SiteCustomization
    class ImagesController < Adm::BaseController
      def update
        authorize [:adm, Setting], :update?

        @image = ::SiteCustomization::Image.find(params[:id])
        @kind = params[:kind].to_sym

        if image_params[:image].present?
          @image.update(image_params) #rubocop:disable Rails/SaveBang
        else
          @image.image.purge_later
          @image.save #rubocop:disable Rails/SaveBang
        end
      end

      private

        def image_params
          params.require(:site_customization_image).permit(:image)
        end
    end
  end
end
