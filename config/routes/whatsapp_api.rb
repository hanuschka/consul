namespace :whatsapp_api, path: "whatsapp_api" do
  post "webhook", to: "webhooks#create"

  # Only mounted where a url_secret is configured, so an environment that never
  # sets one cannot be reached through a credential that ends up in access logs.
  if ::Whatsapp.url_secret.present?
    post "webhook/:url_secret", to: "webhooks#create", as: :webhook_with_url_secret
  end
end
