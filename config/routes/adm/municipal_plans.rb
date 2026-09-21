namespace :adm do
  scope :municipal_plans, module: :municipal_plans, as: :municipal_plans do
    resources :officers, only: [:index, :create, :destroy] do
      post :search, on: :collection
    end

    resources :officer_groups, except: :show

    resources :topics, except: :show do
      patch :order_topics, on: :collection
    end
  end
end
