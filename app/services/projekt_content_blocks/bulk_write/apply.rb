class ProjektContentBlocks::BulkWrite::Apply < ApplicationService
  DEFAULT_MODE = "upsert".freeze

  SERVICES = {
    "append" => ProjektContentBlocks::BulkWrite::Append,
    "prepend" => ProjektContentBlocks::BulkWrite::Prepend,
    "upsert" => ProjektContentBlocks::BulkWrite::Upsert,
    "replace" => ProjektContentBlocks::BulkWrite::Replace,
    "delete" => ProjektContentBlocks::BulkWrite::Delete
  }.freeze

  attr_reader :projekt, :mode, :items

  def initialize(projekt:, mode:, items:)
    @projekt = projekt
    @mode = mode.presence || DEFAULT_MODE
    @items = items
  end

  def call
    service = SERVICES[mode]

    if service.nil?
      raise ProjektContentBlocks::BulkWrite::InvalidRequestError.new(
        "content_blocks_mode" => ["must be one of: #{SERVICES.keys.join(", ")}"]
      )
    end

    service.call(projekt: projekt, items: items)
  end
end
