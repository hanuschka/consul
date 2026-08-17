class Projekts::Copying::ContentBlockCopier < ApplicationService
  def initialize(source:, copy:, record_copier:)
    @source = source
    @copy = copy
    @record_copier = record_copier
    @keys_by_source_key = {}
  end

  # The block body still holds the source's phase ids and image URLs here; the
  # rewiring pass rewrites it once every phase and blob has a copy.
  def call
    source.content_blocks.order(:position, :id).each do |content_block|
      record_copier.copy_record(
        content_block,
        attributes: {
          projekt_id: copy.id,
          key: copy_key_for(content_block.key),
          ai_generation_data: nil
        },
        except: %w[projekt_id key ai_generation_data]
      )
    end
  end

  private

    attr_reader :source, :copy, :record_copier, :keys_by_source_key

    # The key cannot be carried over verbatim. The same source key always maps
    # to the same copy key, which is what keeps a block's per-locale rows
    # paired.
    def copy_key_for(source_key)
      keys_by_source_key[source_key] ||=
        SiteCustomization::ContentBlock.generate_projekt_key(copy.id, keys_by_source_key.size + 1)
    end
end
