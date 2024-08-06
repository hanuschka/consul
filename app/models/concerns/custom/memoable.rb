module Memoable
  extend ActiveSupport::Concern

  included do
    has_many :memos, as: :memoable, dependent: :destroy
  end
end
