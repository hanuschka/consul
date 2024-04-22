resources :communities, only: [:show] do
  resources :topics do
    member do
      post :hide
      post :restore
    end
  end
end

resolve("Topic") { |topic, options| [topic.community, topic, options] }
