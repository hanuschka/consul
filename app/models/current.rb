# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :settings
  attribute :i18n_content_translations

  attribute :frame_current_user
  attribute :frame_csrf_token
  attribute :new_frame_csrf_token
  attribute :frame_session_from_authorized_source
end
