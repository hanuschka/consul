class Memo < ApplicationRecord
  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases
  include Memoable

  has_ancestry touch: true

  belongs_to :memoable, -> { with_hidden }, polymorphic: true
  belongs_to :user, -> { with_hidden }, inverse_of: :memos

  validates :text, presence: true
  validates :memoable, presence: true
  validates :user, presence: true

  alias_attribute :author, :user

  def root_memoable
    root.memoable
  end
end
