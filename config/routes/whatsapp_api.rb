namespace :whatsapp_api, path: "whatsapp_api" do
  # The path-segment variant exists because the 360dialog Hub UI only exposes a
  # webhook URL field; custom headers must be set through their API.
  post "webhook", to: "webhooks#create"
  post "webhook/:secret", to: "webhooks#create", as: :webhook_with_secret
end
