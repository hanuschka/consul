class Newsletter < ApplicationRecord
  include Imageable

  after_initialize :set_default_body, if: :new_record?

  has_many :activities, as: :actionable, inverse_of: :actionable
  belongs_to :recipient_group

  validates :subject, presence: true
  # validates :segment_recipient, presence: true
  validates :from, presence: true, format: { with: /\A.+@.+\Z/ }
  validates :body, presence: true, unless: -> { new_record? }
  # validate :validate_segment_recipient
  validates :recipient_group_id, presence: true

  acts_as_paranoid column: :hidden_at
  include ActsAsParanoidAliases

  def self.default_body
    @default_body_html ||= File.read(
      Rails.root.join("app", "views", "admin", "newsletters", "_default_body.html.erb")
    )
  end

  def list_of_recipient_emails
    return recipient_group.user_emails if recipient_group

    UserSegments.user_segment_emails(segment_recipient) if valid_segment_recipient?
  end

  def valid_segment_recipient?
    UserSegments.valid_segment?(segment_recipient)
  end

  def draft?
    sent_at.nil?
  end

  def deliver
    run_at = first_batch_run_at
    list_of_recipient_emails_in_batches.each do |recipient_emails|
      recipient_emails.each do |recipient_email|
        if valid_email?(recipient_email)
          Mailer.delay(run_at: run_at).newsletter(self, recipient_email)
          log_delivery(recipient_email)
        end
      end
      run_at += batch_interval
    end
  end

  def batch_size
    10000
  end

  def batch_interval
    20.minutes
  end

  def first_batch_run_at
    Time.current
  end

  def list_of_recipient_emails_in_batches
    list_of_recipient_emails.in_groups_of(batch_size, false)
  end

  def email_safe_body(container_width: 620)
    return "" if body.blank?

    doc = Nokogiri::HTML.fragment(body)

    doc.css("figure.image_resized, figure.image").each do |figure|
      img = figure.at_css("img")
      next unless img

      figure_style = figure["style"].to_s
      pct_match = figure_style.match(/width:\s*([\d.]+)%/)

      if pct_match
        pixel_width = (pct_match[1].to_f / 100.0 * container_width).round
        intrinsic_w = img["width"].to_i
        intrinsic_h = img["height"].to_i

        if intrinsic_w > 0 && intrinsic_h > 0
          pixel_height = (pixel_width.to_f / intrinsic_w * intrinsic_h).round
          img["width"] = pixel_width.to_s
          img["height"] = pixel_height.to_s
        else
          img["width"] = pixel_width.to_s
          img.remove_attribute("height")
        end
      end

      img["style"] = img["style"].to_s.gsub(/aspect-ratio:[^;]+;?/, "").strip
      img.remove_attribute("class")

      figure_classes = figure["class"].to_s
      if figure_classes.include?("image-style-align-left")
        img["align"] = "left"
        img["style"] = [img["style"], "max-width:100%;height:auto;margin:0 15px 10px 0;"].compact.reject(&:blank?).join(";")
      elsif figure_classes.include?("image-style-align-right")
        img["align"] = "right"
        img["style"] = [img["style"], "max-width:100%;height:auto;margin:0 0 10px 15px;"].compact.reject(&:blank?).join(";")
      else
        img["style"] = [img["style"], "display:block;margin:0 auto;max-width:100%;height:auto;"].compact.reject(&:blank?).join(";")
      end

      figure.replace(img)
    end

    doc.to_html
  end

  private

    # def validate_segment_recipient
    #   errors.add(:segment_recipient, :invalid) unless valid_segment_recipient?
    # end

    def valid_email?(email)
      email.match(/\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i)
    end

    def log_delivery(recipient_email)
      user = User.find_by(email: recipient_email)
      Activity.log(user, :email, self)
    end

    def set_default_body
      self.body ||= self.class.default_body if Setting["advanced_newsletter"].present?
    end
end
