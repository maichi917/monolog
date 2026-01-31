Rails.application.routes.draw do
  devise_for :users
  root "static_pages#top"

  resources :items, only: %i[index new create show edit update destroy] do
    member do
      patch :start_using
      patch :finish_using

      patch :restock
    end

    collection do
      get :used_up
      get :in_use
    end
  end
end
