class Adm::UserSearchComponent < ApplicationComponent
  attr_reader :url, :label, :description

  def initialize(url:, label:, description: nil)
    @url = url
    @label = label
    @description = description
  end
end
