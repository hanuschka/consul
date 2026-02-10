class Budget
  class ContentBlock < ApplicationRecord
    validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    validates :heading, presence: true, uniqueness: { scope: :locale }

    belongs_to :heading
    delegate :name, to: :heading, allow_nil: true

    before_validation :repair_html_body

    private

    def repair_html_body
      return if body.blank?

      self.body = Nokogiri::HTML::DocumentFragment.parse(body).to_html
    end
  end
end
