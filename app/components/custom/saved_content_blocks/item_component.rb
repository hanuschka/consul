class SavedContentBlocks::ItemComponent < ApplicationComponent
  def initialize(saved_content_block:)
    @saved_content_block = saved_content_block
  end
end
