# The public form shows the choices and input rules of a field; the
# confirmation email it sends is configured by staff only.
class FormularFieldSerializer < BaseSerializer
  PUBLIC_OPTION_KEYS = %w[drop_down_options validates].freeze

  def initialize(formular_field, client: nil)
    @formular_field = formular_field
    @client = client
  end

  def serialize
    {
      id: formular_field.id,
      formular_id: formular_field.formular_id,
      key: formular_field.key,
      kind: formular_field.kind,
      required: formular_field.required,
      given_order: formular_field.given_order,
      follow_up: formular_field.follow_up,
      name: formular_field.name,
      description: formular_field.description,
      translations: serialize_translations(formular_field),
      options: options,
      created_at: formular_field.created_at,
      updated_at: formular_field.updated_at
    }
  end

  private

    attr_reader :formular_field

    def options
      if admin_client?
        formular_field.options
      else
        formular_field.options.slice(*PUBLIC_OPTION_KEYS)
      end
    end
end
