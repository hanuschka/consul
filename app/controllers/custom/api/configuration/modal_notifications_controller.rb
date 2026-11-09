class Api::Configuration::ModalNotificationsController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %w[title html_content].freeze

  ATTRIBUTE_DEFINITIONS = {
    "active_from" => TypedValueParser::Definition.new(type: :date),
    "active_to" => TypedValueParser::Definition.new(type: :date)
  }.freeze

  WRITABLE_ATTRIBUTES = (ATTRIBUTE_DEFINITIONS.keys + %w[translations]).freeze

  before_action :find_modal_notification, only: [:show, :update, :destroy]

  def index
    modal_notifications = paginate(ModalNotification.includes(:translations).order(created_at: :desc))
    current_notification_id = ModalNotification.current&.id

    render json: {
      data: {
        modal_notifications: modal_notifications.map do |modal_notification|
          serialize(modal_notification, current_notification_id)
        end
      },
      pagination: pagination_meta(modal_notifications)
    }
  end

  def show
    render json: {
      data: { modal_notification: serialize(@modal_notification, ModalNotification.current&.id) }
    }
  end

  def create
    save_modal_notification(ModalNotification.new, status: :created)
  end

  def update
    save_modal_notification(@modal_notification, status: :ok)
  end

  def destroy
    @modal_notification.destroy!

    head :no_content
  end

  private

    def find_modal_notification
      @modal_notification = ModalNotification.find(params[:id])
    end

    def save_modal_notification(modal_notification, status:)
      attribute_values, errors = parsed_attributes
      translations = sanitized_translations
      modal_notification.assign_attributes(attribute_values)
      errors = active_period_errors(modal_notification).merge(errors)

      if errors.any?
        return render_invalid_values(errors)
      end

      assign_translations(modal_notification, translations)

      if save_with_translations(modal_notification, translations)
        render json: {
          data: {
            modal_notification: serialize(modal_notification.reload, ModalNotification.current&.id)
          }
        }, status:
      else
        render_translated_record_errors(modal_notification)
      end
    end

    def modal_notification_params
      params.require(:modal_notification)
    end

    def parsed_attributes
      raw_attributes = modal_notification_params.to_unsafe_h
      attribute_values, errors = parse_typed_attributes(raw_attributes, ATTRIBUTE_DEFINITIONS)
      errors.merge!(unknown_attribute_errors(raw_attributes, WRITABLE_ATTRIBUTES))
      errors.merge!(unsupported_locales_error(modal_notification_params[:translations]) || {})

      [attribute_values, errors]
    end

    # The modal renders its HTML through AdminWYSIWYGSanitizer; it is cleaned
    # before it is stored as well, so what the API returns is what is shown.
    def sanitized_translations
      translations = permitted_translations(
        modal_notification_params[:translations], TRANSLATED_ATTRIBUTES
      )

      sanitize_translated_html(translations, "html_content")
    end

    def active_period_errors(modal_notification)
      errors = {}

      if modal_notification.active_from.blank?
        errors["active_from"] = ["can't be blank"]
      end

      if modal_notification.active_to.blank?
        errors["active_to"] = ["can't be blank"]
      elsif modal_notification.active_from && modal_notification.active_to < modal_notification.active_from
        errors["active_to"] = ["must be on or after active_from"]
      end

      errors
    end

    def serialize(modal_notification, current_notification_id)
      {
        id: modal_notification.id,
        active_from: modal_notification.active_from&.iso8601,
        active_to: modal_notification.active_to&.iso8601,
        current: modal_notification.id == current_notification_id,
        translations: serialize_translations(modal_notification, TRANSLATED_ATTRIBUTES),
        created_at: modal_notification.created_at,
        updated_at: modal_notification.updated_at
      }
    end
end
