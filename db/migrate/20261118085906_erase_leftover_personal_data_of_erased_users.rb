class EraseLeftoverPersonalDataOfErasedUsers < ActiveRecord::Migration[7.2]
  DIGEST_FORMAT = /\A\h{64}\z/

  def up
    cleaned = 0

    User.with_hidden.erased.find_each do |user|
      user.update_columns(User::ERASED_PERSONAL_DATA.merge(identity_digests(user)))
      user.send(:remove_audits)
      user.send(:remove_subscriptions)
      user.send(:remove_personal_records)
      cleaned += 1
    end

    say "users: removed the leftover personal data of #{cleaned} erased accounts"
  end

  def down
  end

  private

    def identity_digests(user)
      stamp = user.unique_stamp.presence || user.prepare_unique_stamp
      digests = {}
      digests[:unique_stamp] = User.erased_identifier(stamp) unless digest?(stamp)
      unless digest?(user.document_number)
        digests[:document_number] = User.erased_document_identifier(user.document_number, user.document_type)
      end
      digests
    end

    def digest?(value)
      DIGEST_FORMAT.match?(value.to_s)
    end
end
