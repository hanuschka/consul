devise_version = Gem.loaded_specs["devise"].version.to_s

if devise_version != "4.9.3"
  raise(
    "devise #{devise_version} is not the version config/initializers/" \
    "devise_security_backports.rb was written for; devise 5.0.4+ ships " \
    "both fixes, so delete this file when upgrading to it"
  )
end

# Without the forced write, a concurrent email change could leave the token of
# one request next to the unconfirmed_email of the other (Devise 5.0.3 fix).
module DeviseConfirmableEmailChangeRace
  protected

    def postpone_email_change_until_confirmation_and_regenerate_confirmation_token
      super
      unconfirmed_email_will_change!
    end
end

# A timed-out non-GET request redirected to the raw Referer, so a cross-site
# form could send the user to any external URL (Devise 5.0.4 fix).
module DeviseTimeoutRedirect
  protected

    def redirect_url
      if warden_message == :timeout && !request.get?
        if is_flashing_format?
          flash[:timedout] = true
        end

        extract_path_from_location(request.referrer) || scope_url
      else
        super
      end
    end
end

Devise::Models::Confirmable.prepend(DeviseConfirmableEmailChangeRace)
Devise::FailureApp.prepend(DeviseTimeoutRedirect)
