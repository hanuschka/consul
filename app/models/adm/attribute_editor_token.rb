# The /adm attribute endpoint saves whichever field the form names. The name
# is checked against this signature instead of trusted, so a browser can only
# write the record, field and editor kind the server rendered for it.
class Adm::AttributeEditorToken
  PURPOSE = "adm_attribute_editor".freeze

  class << self
    def generate(record, attribute, kind)
      verifier.generate(payload(record, attribute, kind), purpose: PURPOSE)
    end

    # A query parameter can arrive as an array or a hash, hence the type check.
    def valid?(token, record, attribute, kind)
      return false if !token.is_a?(String)

      verifier.verified(token, purpose: PURPOSE) == payload(record, attribute, kind)
    end

    private

      def payload(record, attribute, kind)
        [record.class.base_class.name, record.id, attribute.to_s, kind.to_s]
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
  end
end
