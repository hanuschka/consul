# The admin profile trusts markup an admin typed. A content block the import
# renders is filled from a third-party document by a model, so the elements
# that make a page collect input are dropped; a phishing form on a municipal
# domain is the failure this prevents, and no template asks for one.
class ImportContentBlockSanitizer < AdminWYSIWYGSanitizer
  INPUT_TAGS = %w[form input textarea button label object embed param].freeze

  def allowed_tags
    super - INPUT_TAGS
  end
end
