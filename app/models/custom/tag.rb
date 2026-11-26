load Rails.root.join("app", "models", "tag.rb")

class Tag < ActsAsTaggableOn::Tag
  # Only categories are configuration; tags users add to their contributions
  # are created and counted far too often to audit.
  audited only: %i[name kind], if: :category?
end
