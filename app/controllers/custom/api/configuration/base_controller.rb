# Base for every endpoint that changes the instance configuration: only clients
# granted the configuration right get through, and each change is audited
# under the client's content author with the client id on the audit row.
class Api::Configuration::BaseController < Api::BaseController
  before_action :check_configuration_access!
  around_action :audit_changes_as_client

  private

    # Checks each attribute present in the body against its definition and
    # returns the typed values plus the errors per attribute.
    def parse_typed_attributes(raw_attributes, definitions)
      attribute_values = {}
      errors = {}

      definitions.each do |name, definition|
        next if !raw_attributes.key?(name)

        result = TypedValueParser.parse(raw_attributes[name], definition)

        if result.valid?
          attribute_values[name] = result.value
        else
          errors[name] = [result.error]
        end
      end

      [attribute_values, errors]
    end

    def unknown_attribute_errors(raw_attributes, writable_attribute_names)
      (raw_attributes.keys - writable_attribute_names).index_with { ["is not a writable attribute"] }
    end
end
