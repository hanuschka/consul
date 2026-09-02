# A read-only pass for one single resource, carried in a signed link rather than a column: signing
# the record's global id keeps the pass to that one record, and needs no lookup table and no cleanup.
#
# The purpose is the caller's, not this class's — it is mixed into the signature, so a token minted
# for one feature does not verify for another. Callers hold their own purpose constant next to the
# code that mints the link; see OnBehalfOfAccountMailer::PREVIEW_PURPOSE.
class ResourcePreviewToken
  class << self
    def generate(resource, purpose:, expires_in:)
      return if resource.blank? || !resource.respond_to?(:to_gid)

      verifier(purpose).generate(resource.to_gid.to_s, purpose: purpose, expires_in: expires_in)
    end

    # Returns the signed global id, or nil for anything tampered with, expired, absent, minted for
    # another purpose, or not even a string — a query parameter can arrive as an array. The caller
    # gets the id rather than the record: it is used to grant an ability, which needs only the class
    # and the id, and a token for a record since deleted has to come back empty instead of raising.
    def resource_gid(token, purpose:)
      return unless token.is_a?(String)
      return if token.blank?

      verifier(purpose).verified(token, purpose: purpose)
    end

    private

      def verifier(purpose)
        Rails.application.message_verifier(purpose)
      end
  end
end
