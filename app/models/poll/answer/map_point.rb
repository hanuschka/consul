class Poll::Answer::MapPoint < ApplicationRecord
  belongs_to :answer, class_name: "Poll::Answer", foreign_key: :poll_answer_id,
                      inverse_of: :map_points

  validates :latitude, presence: true,
                       numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  scope :for_question, ->(question) {
    joins(:answer).where(poll_answers: { question_id: question })
  }

  def to_feature
    {
      "type" => "Feature",
      "geometry" => {
        "type" => "Point",
        "coordinates" => [longitude, latitude]
      },
      "properties" => {
        "id" => id
      }
    }
  end
end
