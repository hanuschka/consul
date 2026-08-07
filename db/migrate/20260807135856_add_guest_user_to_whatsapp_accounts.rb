class AddGuestUserToWhatsappAccounts < ActiveRecord::Migration[6.1]
  # A phase set to guest participation accepts submissions with no account, and
  # the bot now honours that — but a proposal still needs an author. The web
  # mints a guest per browser session and forgets it; a phone number is a
  # steadier identity than a cookie, so the guest is kept on the account. That
  # is what lets a phase's per-user submission limit still mean something when
  # the same number writes in again.
  #
  # Held apart from user_id: that column means "this number belongs to a real
  # Consul account", and a guest standing in it would make every linked? check
  # answer wrong.
  def change
    add_reference :whatsapp_accounts, :guest_user, index: { unique: true }
  end
end
