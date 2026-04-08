class ProgressBarSerializer < BaseSerializer
  attr_reader :progress_bar

  def initialize(progress_bar)
    @progress_bar = progress_bar
  end

  def serialize
    data = progress_bar.as_json(
      only: [
        :id,
        :kind,
        :percentage,
        :progressable_type,
        :progressable_id,
        :created_at,
        :updated_at
      ]
    )

    data[:title] = progress_bar.title

    data
  end

  def self.serialize_collection(progress_bars)
    progress_bars.map { |pb| new(pb).serialize }
  end
end
