class Newsletter < ApplicationRecord
  include Imageable

  after_initialize :set_default_body, if: :new_record?

  has_many :activities, as: :actionable, inverse_of: :actionable
  has_many :content_blocks,
           -> { order(:position) },
           class_name: "SiteCustomization::ContentBlock",
           dependent: :destroy
  belongs_to :recipient_group

  validates :subject, presence: true
  # validates :segment_recipient, presence: true
  validates :from, presence: true, format: { with: /\A.+@.+\Z/ }
  validates :body, presence: true, unless: -> { new_record? || content_blocks.exists? }
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
    emails =
      if recipient_group
        recipient_group.user_emails
      elsif valid_segment_recipient?
        UserSegments.user_segment_emails(segment_recipient)
      end

    return emails if emails.blank?
    return emails unless respect_newsletter_optout?

    optin_emails = User.actual.where(newsletter: true).pluck(:email).compact +
                   UnregisteredNewsletterSubscriber.confirmed.pluck(:email).compact
    optin_set = optin_emails.to_set
    emails.select { |e| optin_set.include?(e) }
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

  def renders_from_content_blocks?
    draft? && content_blocks.exists?
  end

  def composed_content_blocks_html
    content_blocks.map do |content_block|
      margin = content_block.margin_bottom || SiteCustomization::ContentBlock::DEFAULT_MARGIN_BOTTOM

      %(<div style="margin-bottom:#{margin}px;">#{content_block.body}</div>)
    end.join("\n")
  end

  def snapshot_content_blocks_to_body!
    return if !renders_from_content_blocks?

    update_column(:body, composed_content_blocks_html)
  end

  def email_safe_body(container_width: 620)
    source_html = renders_from_content_blocks? ? composed_content_blocks_html : body
    return "" if source_html.blank?

    doc = Nokogiri::HTML.fragment(source_html)

    doc.css("figure.image_resized, figure.image").each do |figure|
      img = figure.at_css("img")
      next unless img

      figure_style = figure["style"].to_s
      pct_match = figure_style.match(/width:\s*([\d.]+)%/)

      if pct_match
        pixel_width = (pct_match[1].to_f / 100.0 * container_width).round
        img["width"] = pixel_width.to_s
      end

      img.remove_attribute("height")
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

    doc.css("img").each do |img|
      img.remove_attribute("height")
      style = img["style"].to_s.gsub(/height\s*:[^;]+;?/i, "").strip
      style << ";" unless style.empty? || style.end_with?(";")
      style << "height:auto;" unless style =~ /height\s*:\s*auto/i
      style << "max-width:100%;" unless style =~ /max-width\s*:/i
      img["style"] = style
    end

    doc.css("a[href], img[src]").each do |node|
      attr = node.name == "a" ? "href" : "src"
      url = node[attr].to_s
      next if url.blank?
      next if url.match?(/\A(?:https?:|mailto:|tel:|cid:|data:|#)/i)

      begin
        node[attr] = URI.join(Setting["url"].to_s, url).to_s
      rescue URI::InvalidURIError
        next
      end
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
