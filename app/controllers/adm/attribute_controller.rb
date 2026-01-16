module Adm
  class AttributeController < Adm::BaseController
    include Translatable

    def update
      @record = find_record
      authorize [:adm, @record]
      @kind = params[:kind]&.to_sym

      if @record.update(permitted_params)
        flash.now[:success] = t(".success")
      end

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@record, params[:attribute]),
        Adm::AttributeEditorComponent.new(@record, params[:attribute], params[:kind])
      )
    end

    private

      def find_record
        record_class = params[:record_type].classify.constantize
        record_class.find(params[:id])
      end

      def permitted_params
        param_key = params[:record_type].tr("/", "_").to_sym
        record_class = params[:record_type].classify.constantize
        attribute = params[:attribute].to_sym

        if translated_attribute?(record_class, attribute)
          params.require(param_key).permit(translation_params(record_class))
        else
          params.require(param_key).permit(attribute)
        end
      end

      def translated_attribute?(record_class, attribute)
        record_class.respond_to?(:translated_attribute_names) &&
          record_class.translated_attribute_names.include?(attribute)
      end
  end
end
