class Projekts::ConvertToNewContentBlockMode < ApplicationService
  attr_reader :projekt

  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    return ServiceResult.failure(error: "already_converted") if projekt.new_content_block_mode?

    ActiveRecord::Base.transaction do
      create_content_block_from_page_content
      projekt.update!(new_content_block_mode: true)
    end

    ServiceResult.success
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.failure(error: e.message)
  end

  private

    def create_content_block_from_page_content
      content_block = projekt.content_blocks.create!(
        name: "custom",
        body: projekt.page&.content.to_s,
        key: "projekt_content_block_#{projekt.id}_#{projekt.content_blocks.count + 1}_#{DateTime.now.to_i}",
        locale: "de"
      )

      content_block.move_to_top
    end
end
