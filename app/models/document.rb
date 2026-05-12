class Document < ApplicationRecord
  include Attachable

  belongs_to :user
  belongs_to :documentable, polymorphic: true, touch: true

  validates :title, presence: true
  validates :user_id, presence: true
  validates :documentable_id, presence: true,         if: -> { persisted? && !admin? }
  validates :documentable_type, presence: true,       if: -> { persisted? && !admin? }

  scope :admin, -> { where(admin: true) }

  scope :for_studio_file_manager, ->(projekt) {
    if projekt
      where(admin: true, documentable_type: "Projekt", documentable_id: projekt.id)
    else
      where(admin: true, documentable_id: nil)
    end
  }

  def self.accepted_content_types
    Setting["uploads.documents.content_types"]&.split(" ") || %w[application/pdf]
  end

  def self.max_file_size
    Setting["uploads.documents.max_size"].to_i.nonzero? || 10
  end

  def self.humanized_accepted_content_types
    Setting.accepted_content_types_for("documents").join(", ")
  end

  def humanized_content_type
    attachment_content_type&.split("/")&.last&.upcase
  end

  def max_file_size
    documentable_class&.max_file_size || self.class.max_file_size
  end

  def accepted_content_types
    documentable_class&.accepted_content_types || self.class.accepted_content_types
  end

  private

    def association_name
      :documentable
    end

    def documentable_class
      association_class
    end
end
