  namespace :api do
    resources :projekts, shallow: true do
      resources :projekt_phases
      resources :content_blocks do
        collection do
          post :reorder
        end
      end
    end
  end
