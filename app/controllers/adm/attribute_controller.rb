module Adm
  class AttributeController < Adm::BaseController
    include Translatable

    def update
      @record = find_record
      authorize @record, :update?, policy_class: policy_class_for(@record)
      @kind = params[:kind]&.to_sym

      if ai_gated_blocked?
        flash.now[:error] = t("adm.ai_required_note")
      elsif attachment_kind? && remove_attachment_requested? && @record.class.reflect_on_attachment(params[:attribute].to_sym)
        @record.send(params[:attribute]).purge
        flash.now[:success] = t(".success")
      elsif @kind == :image && imageable_image_attribute?
        if params[:remove_attachment] == "1"
          remove_imageable_image
        else
          update_imageable_image
        end
      elsif @kind == :content_types
        if @record.update(value: submitted_content_types)
          flash.now[:success] = t(".success")
        end
      elsif @record.update(permitted_params)
        flash.now[:success] = t(".success")
        register_whatsapp_webhook_if_enabled
      end

      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(@record, params[:attribute]),
        Adm::AttributeEditorComponent.new(@record, params[:attribute], params[:kind], **component_options)
      )
    end

    private

      # Switching the bot on is the only moment we know both that WhatsApp should
      # be live and which host the admin is working on, so the webhook is pushed
      # to 360dialog from here rather than from a rake task or console.
      def register_whatsapp_webhook_if_enabled
        return if !@record.is_a?(::Setting)
        return if @record.key != "feature.whatsapp_bot"
        return if !@record.saved_change_to_value?
        return if @record.value.blank?

        ::Whatsapp::RegisterWebhookJob.perform_later(request.base_url)
      end

      def attachment_kind?
        [:image, :video].include?(@kind)
      end

      def remove_attachment_requested?
        params[:remove_attachment] == "1" ||
          params.dig(@record.model_name.param_key, :_destroy) == "1"
      end

      def find_record
        record_class = params[:record_type].tr("-", "/").classify.constantize
        record_class.find(params[:id])
      end

      def permitted_params
        param_key = @record.model_name.param_key.to_sym
        attribute = params[:attribute].to_sym

        params.require(param_key).permit(attribute)
      end

      def submitted_content_types
        Array(params[:content_types]).reject(&:blank?).join(" ")
      end

      def imageable_image_attribute?
        reflection = @record.class.reflect_on_association(params[:attribute].to_sym)
        reflection.present? && reflection.klass.name == "Image"
      end

      def update_imageable_image
        attachment = params.dig(@record.model_name.param_key.to_sym, params[:attribute].to_sym)
        return unless attachment

        image = @record.public_send(params[:attribute]) || ::Image.new(imageable: @record)
        image.attachment = attachment
        image.user = current_user

        if image.save
          @record.association(params[:attribute].to_sym).reset
          flash.now[:success] = t(".success")
        end
      end

      def remove_imageable_image
        image = @record.public_send(params[:attribute])
        image&.destroy
        @record.association(params[:attribute].to_sym).reset
        flash.now[:success] = t(".success")
      end

      def component_options
        options = {}
        options[:select_options] = JSON.parse(params[:select_options]) if params[:select_options].present?
        options[:wide] = true if params[:wide].present?
        options[:hide_label] = true if params[:hide_label].present?
        options[:inline] = true if params[:inline].present?
        options[:toolbar] = params[:toolbar] if params[:toolbar].present?
        options[:divider] = ActiveModel::Type::Boolean.new.cast(params[:divider]) if params.key?(:divider)
        options[:ai_gated] = true if params[:ai_gated].present?
        options
      end

      def ai_gated_blocked?
        return false if !@record.respond_to?(:ai_gated?) || !@record.ai_gated?
        return false if Ai::Settings.ai_available?

        ActiveModel::Type::Boolean.new.cast(submitted_attribute_value) == true
      end

      def submitted_attribute_value
        permitted_params[params[:attribute]]
      rescue ActionController::ParameterMissing
        nil
      end
  end
end
