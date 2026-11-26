class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  class ForbiddenError < StandardError; end
  class UnauthorizedError < StandardError; end

  class UnsupportedLocalesError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.values.flatten.to_sentence)
    end
  end

  # Rendered by the handlers below; actions that rescue StandardError
  # themselves re-raise these so every endpoint answers them the same way.
  SELF_RENDERED_ERRORS = [
    ForbiddenError,
    UnauthorizedError,
    UnsupportedLocalesError,
    ActionController::ParameterMissing,
    ActiveRecord::RecordInvalid,
    ActiveRecord::RecordNotUnique,
    Base64Attachable::InvalidEncoding
  ].freeze

  DEFAULT_PER_PAGE = 500
  COMMENTS_PER_PAGE = 5000
  MAX_PER_PAGE = 2000

  before_action :authenticate_http_basic, if: :require_http_basic_auth?
  before_action :authenticate_api_client!

  BODY_PARAM_MAX_BYTES = 8192

  rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ForbiddenError, with: :render_forbidden
  rescue_from UnauthorizedError, with: :render_unauthorized
  rescue_from ActionController::ParameterMissing, with: :render_missing_parameter
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_unparsable_body
  rescue_from Base64Attachable::InvalidEncoding, with: :render_invalid_attachment
  rescue_from UnsupportedLocalesError, with: :render_unsupported_locales
  rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record
  rescue_from ActiveRecord::RecordNotUnique, with: :render_conflicting_record

  private

    def authenticate_http_basic
      authenticate_or_request_with_http_basic do |username, password|
        username == Rails.application.secrets.http_basic_username && password == Rails.application.secrets.http_basic_password
      end
    end

    def http_basic_auth_site?
      Rails.application.secrets.http_basic_auth
    end

    def require_http_basic_auth?
      http_basic_auth_site? && !bearer_token_provided?
    end

    def bearer_token_provided?
      request.authorization.to_s.match?(/\ABearer /i)
    end

    def authenticate_api_client!
      token = request.headers["Authorization"]&.split(" ")&.last
      client = ApiClient.find_by(access_token: token)

      if client.present?
        @current_client = client
        @internal_api_client = false
      else
        internal_client = InternalApiClient.find_by(auth_token: token)

        if internal_client.present?
          @current_client = internal_client
          @internal_api_client = true
        else
          raise UnauthorizedError, "Invalid or missing API token."
        end
      end
    end

    def current_client
      @current_client
    end

    def internal_api_client?
      @internal_api_client == true
    end

    def admin_client?
      current_client.present? && current_client.admin?
    end

    # Documents arrive without an author: the API never lets a client choose
    # whom a file is attributed to.
    def assign_document_authors(resource)
      resource.documents.select(&:new_record?).each do |document|
        document.user = current_client.content_author
      end
    end

    def check_read_access!
      return if internal_api_client?

      unless current_client&.can_read_public_data?
        raise ForbiddenError, "You do not have permission to read this resource."
      end
    end

    def check_admin_access!
      return if internal_api_client?

      unless current_client&.admin?
        raise ForbiddenError, "You do not have permission to perform this action. Admin access required."
      end
    end

    # Unlike check_admin_access!, internal clients are not let through: the
    # right has to be granted to the client explicitly in /adm.
    def check_configuration_access!
      return if configuration_client?

      raise ForbiddenError,
        "You do not have permission to change the instance configuration. " \
        "The API client needs the instance configuration access right."
    end

    def configuration_client?
      !internal_api_client? && current_client.can_configure_instance?
    end

    # Audit rows written during the action carry the client's content author
    # as their user (the audit views and SectionTrackable expect a User) and
    # the client itself in their comment.
    def audit_changes_as_client(&)
      Current.api_client = current_client
      audit_user = internal_api_client? ? User.system : current_client.content_author

      ::Audit.as_user(audit_user, &)
    ensure
      Current.api_client = nil
    end

    def render_forbidden(exception)
      render json: {
        error: {
          type: "forbidden",
          messages: [exception.message]
        }
      }, status: :forbidden
    end

    def render_unauthorized(exception)
      render json: {
        error: {
          type: "unauthorized",
          messages: [exception.message]
        }
      }, status: :unauthorized
    end

    def render_not_found
      render json: {
        error: { type: "not_found", messages: ["Not found"] }
      }, status: :not_found
    end

    def render_missing_parameter(exception)
      render_bad_request(
        "The request body must contain a non-empty '#{exception.param}' object."
      )
    end

    def render_unparsable_body
      render_bad_request("The request body is not valid JSON.")
    end

    def render_bad_request(message)
      render json: {
        error: { type: "bad_request", messages: [message] }
      }, status: :bad_request
    end

    def render_invalid_attachment(exception)
      render json: {
        error: { type: "unprocessable_entity", messages: [exception.message] }
      }, status: :unprocessable_entity
    end

    def render_invalid_values(errors)
      render json: {
        error: {
          type: "unprocessable_entity",
          messages: errors.map { |field, messages| "#{field} #{Array(messages).to_sentence}" },
          details: errors
        }
      }, status: :unprocessable_entity
    end

    def render_unsupported_locales(exception)
      render_invalid_values(exception.errors)
    end

    def render_invalid_record(exception)
      render_translated_record_errors(exception.record)
    end

    # A unique index caught what no validation checked first, e.g. two
    # requests creating the same external id at once.
    def render_conflicting_record
      render_invalid_values({ "base" => ["conflicts with an existing record"] })
    end

    def render_record_errors(record)
      render_invalid_values(record.errors.to_hash(true).transform_keys(&:to_s))
    end

    # Globalize keeps the errors of a translation row (a language written
    # without its required title) on that row, not on the record; they are
    # reported as translations.<locale>.<attribute>.
    def render_translated_record_errors(record)
      errors = record.errors.to_hash(true).transform_keys(&:to_s)

      if record.respond_to?(:translations)
        record.translations.each do |translation|
          translation.errors.to_hash(true).each do |attribute, messages|
            errors["translations.#{translation.locale}.#{attribute}"] = messages
          end
        end
      end

      render_invalid_values(errors)
    end

    def available_locales
      I18n.available_locales.map(&:to_s)
    end

    # Translations arrive as { "de" => { "title" => "…" }, "en" => { … } }.
    # Each language is written through Globalize directly, so no translation ids
    # are needed.
    def assign_translations(record, translations)
      translations.each do |locale, attributes|
        Globalize.with_locale(locale) { record.assign_attributes(attributes) }
      end
    end

    # Reads the body's `<resource_key>.translations`, rejects languages the
    # instance doesn't offer and assigns the rest; returns what was assigned
    # so the save can tell how many languages were written.
    def assign_requested_translations(record, resource_key, attribute_names)
      translations_param = params.dig(resource_key, :translations)
      locales_error = unsupported_locales_error(translations_param)

      if locales_error.present?
        raise UnsupportedLocalesError, locales_error
      end

      translations = permitted_translations(translations_param, attribute_names)
      assign_translations(record, translations)

      translations
    end

    # Several languages in one request switch machine translation off: it would
    # otherwise overwrite the languages the client just wrote. Top-level fields
    # and `translations_attributes` count as written languages too.
    def save_with_translations(record, translations)
      written_locales = translations.keys.map(&:to_s) | changed_translation_locales(record)

      if written_locales.size > 1
        MachineTranslation.suppress { record.save }
      else
        record.save
      end
    end

    def changed_translation_locales(record)
      return [] if !record.respond_to?(:globalize)

      stashed_locales = record.globalize.stash.keys.select { record.globalize.changes(it).any? }
      nested_locales = record.translations.select(&:changed?).map(&:locale)

      (stashed_locales + nested_locales).map(&:to_s).uniq
    end

    def permitted_translations(translations_param, attribute_names)
      if !translations_param.is_a?(ActionController::Parameters)
        return {}
      end

      translations_param
        .permit(available_locales.index_with { attribute_names })
        .to_h
        .slice(*available_locales)
    end

    def serialize_translations(record, attribute_names)
      TranslationsSerializer.new(record, attribute_names).serialize
    end

    def unsupported_locales_error(translations_param)
      return if !translations_param.is_a?(ActionController::Parameters)

      unknown_locales = translations_param.to_unsafe_h.keys - available_locales
      return if unknown_locales.empty?

      { "translations" => ["contain unsupported languages: #{unknown_locales.join(", ")}"] }
    end

    # HTML is cleaned on the way in, so no script ever reaches the database.
    def sanitize_translated_html(translations, attribute_name)
      translations.transform_values do |attributes|
        if attributes[attribute_name].present?
          attributes.merge(attribute_name => AdminWYSIWYGSanitizer.new.sanitize(attributes[attribute_name]))
        else
          attributes
        end
      end
    end

    # `accepts_nested_attributes_for :map_location` builds a new row when the
    # body carries no id, dropping the old one with its screenshot and
    # derived address; an update without an id means the existing location.
    def with_existing_map_location_id(record, resource_attributes)
      map_location_attributes = resource_attributes[:map_location_attributes]
      return resource_attributes if map_location_attributes.blank?
      return resource_attributes if record.map_location.blank?
      return resource_attributes if map_location_attributes[:id].present?

      resource_attributes.merge(
        map_location_attributes: map_location_attributes.merge(id: record.map_location.id)
      )
    end

    def attachment_url(attachment)
      return nil if !attachment&.attached?

      rails_blob_url(attachment, **UrlOptions.default)
    end

    def serialize_attachment(attachment)
      return nil if !attachment&.attached?

      {
        url: attachment_url(attachment),
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size
      }
    end

    # Swapping or removing a file changes no column, so the audited gem would
    # not see it; the change is written as an audit row of its own.
    def audit_attachment_change(record, attribute_name, previous_blob, current_blob)
      ::Audit.create!(
        auditable: record,
        action: "update",
        audited_changes: {
          attribute_name.to_s => [blob_audit_label(previous_blob), blob_audit_label(current_blob)]
        }
      )
    end

    def blob_audit_label(blob)
      return nil if blob.nil?

      "#{blob.filename} (#{blob.checksum})"
    end

    # Files arrive base64 encoded, bare or as a data URI.
    def decoded_attachment(encoded_file, filename_stem)
      if !encoded_file.is_a?(String) || encoded_file.blank?
        raise ActionController::ParameterMissing, :attachment
      end

      Base64Attachable.build(encoded_file, filename_stem:)
    end

    def publicly_visible_phase?(projekt_phase)
      projekt_phase.frontend_visibility &&
        projekt_phase.active? &&
        Projekt.visible_projekt_ids_for(nil).include?(projekt_phase.projekt_id)
    end

    def phase_hidden_from_client?(projekt_phase)
      current_client.public_data? && !publicly_visible_phase?(projekt_phase)
    end

    # Lists give read-only clients only content of visible phases, so a
    # record outside any phase is denied to them as well.
    def check_phase_visible!(projekt_phase)
      phase_hidden =
        if projekt_phase.nil?
          current_client.public_data?
        else
          phase_hidden_from_client?(projekt_phase)
        end

      if phase_hidden
        raise ForbiddenError, "Access denied"
      end
    end

    def poll_vote_totals(poll, question_ids)
      if PollSerializer.results_visible?(poll, current_client)
        Polls::AnswerVoteTotals.call(question_ids)
      end
    end

    def restrict_to_public_phases(scope)
      scope
        .joins(:projekt_phase)
        .where(projekt_phases: public_phase_conditions)
    end

    def public_phase_conditions
      {
        frontend_visibility: true,
        active: true,
        projekt_id: Projekt.visible_for(nil).select(:id)
      }
    end

    # Clients send document files as base64 strings, which Active Storage
    # cannot take as they are.
    def with_decoded_documents(permitted_params)
      resource_attributes = permitted_params.to_h
      documents = resource_attributes[:documents_attributes]
      return resource_attributes if documents.blank?

      document_list = documents.is_a?(Array) ? documents : documents.values

      document_list.each do |document|
        encoded_file = document[:attachment]
        next if !encoded_file.is_a?(String) || encoded_file.blank?

        document[:attachment] = Base64Attachable.build(
          encoded_file,
          filename_stem: document[:title]
        )
      end

      resource_attributes
    end

    def paginate(scope, default_per_page: DEFAULT_PER_PAGE)
      scope.page(params[:page].to_s).per(requested_per_page(default_per_page))
    end

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end

    def empty_pagination_meta(default_per_page: DEFAULT_PER_PAGE)
      {
        current_page: 1,
        total_pages: 0,
        total_count: 0,
        per_page: requested_per_page(default_per_page)
      }
    end

    def requested_per_page(default_per_page)
      cap = [MAX_PER_PAGE, default_per_page].max
      requested = params[:per_page].to_s.to_i

      if requested < 1
        default_per_page
      else
        [requested, cap].min
      end
    end

    def no_pagination_meta
      {
        message: "All matching records were returned in a single response " \
          "without pagination. To paginate, supply the 'page' and/or " \
          "'per_page' query parameters (for example: ?page=1&per_page=20)."
      }
    end

    def append_info_to_payload(payload)
      super
      return if skip_api_request_log?

      payload[:api_request_log] = {
        full_url: request.url,
        query_params: request.query_parameters.to_h,
        body_params: loggable_body_params,
        api_client_id: @current_client&.id
      }
    rescue StandardError
    end

    def loggable_body_params
      request.request_parameters.to_h.deep_transform_values do |value|
        if value.is_a?(String) && value.bytesize > BODY_PARAM_MAX_BYTES
          "[truncated #{value.bytesize} bytes]"
        else
          value
        end
      end
    end

    SKIP_LOG_RESPONSE_STATUSES = [401, 403, 404, 405].freeze

    def skip_api_request_log?
      return true if @current_client.blank?

      SKIP_LOG_RESPONSE_STATUSES.include?(response.status)
    end

    def render_internal_server_error(exception)
      raise exception if !Rails.env.production?

      Sentry.capture_exception(exception)
      Rails.logger.error("[API] #{exception.class} (#{exception.message}):\n#{exception.backtrace.join("\n")}")

      render json: {
        error: {
          type: "internal_server_error",
          messages: ["Internal server error"]
        }
      }, status: :internal_server_error
    end

  protected

  # Processes base64-encoded image data and creates/updates an Image resource
  # @param resource [Object] The imageable resource (Project, Proposal, etc.)
  # @param image_data [Hash] Hash containing :title, :attachment, :credits, :ai_generated, :_destroy
  # @return [Image, nil] The updated/created Image object or nil if destroyed
  # @raises [StandardError] If base64 decoding or image operations fail
    def process_image_with_base64(resource, image_data)
      return nil if image_data.blank?

      if ActiveModel::Type::Boolean.new.cast(image_data[:_destroy])
        resource.image&.destroy
        return nil
      end

      if image_data[:attachment].present?
        return update_image_with_attachment(resource, image_data)
      end

      image = resource.image
      return nil if image.blank?

      assign_image_fields(image, image_data)
      image.save!

      image
    end

  private

    def update_image_with_attachment(resource, image_attrs)
      attachment_data = image_attrs[:attachment]
      content_type = Base64ImageUtils.content_type_from_string(attachment_data)
      extension = Base64ImageUtils.extension_from_content_type(content_type)
      filename = "image.#{extension}"

      new_temp_file = Base64ImageUtils.decode_to_tempfile(attachment_data)
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: new_temp_file,
        filename:,
        type: content_type
      )

      image = resource.image || Image.new(
        user: User.administrators.first || User.first,
        imageable: resource
      )

      # Assigned and saved through the record rather than attached directly:
      # attachment.attach writes immediately and skips the model callbacks, so
      # the AI marker of the picture being replaced would survive onto the new
      # file.
      image.attachment = uploaded_file
      assign_image_fields(image, image_attrs)
      image.save!

      image

    ensure
      if new_temp_file
        new_temp_file.close
        new_temp_file.unlink
      end
    end

    # The image's own fields travel in the same hash as the attachment, and are
    # documented as writable, so a payload that carries only them still has to
    # land on the existing image.
    def assign_image_fields(image, image_attrs)
      image.title = image_attrs[:title] if image_attrs.key?(:title)
      image.credits = image_attrs[:credits] if image_attrs.key?(:credits)

      if image_attrs.key?(:ai_generated)
        image.ai_generated = ActiveModel::Type::Boolean.new.cast(image_attrs[:ai_generated]) == true
      end
    end
end
