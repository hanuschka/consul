# frozen_string_literal: true

class Shared::ImageCreditComponent < ApplicationComponent
  attr_reader :credits

  def initialize(credits:)
    @credits = credits
  end

  def render?
    credits.present?
  end
end
