module Adm
  class AttributeController < Adm::BaseController
    include Translatable

    def update
      @record = find_record
      authorize @record, :update?, policy_class: policy_class_for(@record)
      @kind = params[:kind]&.to_sym

      if @kind == :image && params[:remove_image] == "1" && @record.class.reflect_on_attachment(params[:attribute].to_sym)
        @record.send(params[:attribute]).purge
        flash.now[:success] = t(".success")
      elsif @record.update(permitted_params)
        flash.now[:success] = t(".success")
      end

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@record, params[:attribute]),
        Adm::AttributeEditorComponent.new(@record, params[:attribute], params[:kind], **component_options)
      )
    end

    private

      def find_record
        record_class = params[:record_type].tr("-", "/").classify.constantize
        record_class.find(params[:id])
      end

      def permitted_params
        param_key = @record.model_name.param_key.to_sym
        attribute = params[:attribute].to_sym

        params.require(param_key).permit(attribute)
      end

      def component_options
        options = {}
        options[:select_options] = JSON.parse(params[:select_options]) if params[:select_options].present?
        options[:wide] = true if params[:wide].present?
        options[:hide_label] = true if params[:hide_label].present?
        options[:inline] = true if params[:inline].present?
        options[:divider] = ActiveModel::Type::Boolean.new.cast(params[:divider]) if params.key?(:divider)
        options
      end
  end
end
