class Projekts::Copying::ContentBlockCopier < ApplicationService
  def initialize(bundle:, copy:, record_copier:)
    @bundle = bundle
    @copy = copy
    @record_copier = record_copier
    @keys_by_source_key = {}
  end

  # The block body still holds the source's phase ids and, within one instance,
  # its image URLs; the rewiring pass rewrites both once every phase and blob
  # has a copy. An imported body arrives with placeholders already in place.
  def call
    Array(bundle["content_blocks"]).each do |node|
      record_copier.copy_record(
        node,
        attributes: {
          projekt_id: copy.id,
          key: copy_key_for(node["source_key"]),
          ai_generation_data: nil
        }
      )
    end
  end

  private

    attr_reader :bundle, :copy, :record_copier, :keys_by_source_key

    # The key cannot be carried over verbatim. The same source key always maps
    # to the same copy key, which is what keeps a block's per-locale rows
    # paired.
    def copy_key_for(source_key)
      keys_by_source_key[source_key] ||=
        SiteCustomization::ContentBlock.generate_projekt_key(copy.id, keys_by_source_key.size + 1)
    end
end
