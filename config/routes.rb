Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  devise_for :users
  root "static_pages#top"
  get "guide", to: "static_pages#guide", as: :guide
  get "terms", to: "static_pages#terms", as: :terms
  get "privacy", to: "static_pages#privacy", as: :privacy
  get "contact", to: "static_pages#contact", as: :contact

  resources :items, only: %i[index new create show edit update destroy] do
    member do
      patch :start_using
      get :finish_using_form, path: :finish_using
      patch :finish_using
      get :discontinue_using_form, path: :discontinue_using
      patch :discontinue_using
      patch :toggle_favorite
      delete :image, action: :destroy_image
    end

    collection do
      get :used_up
      get :discontinued
      get :in_use
    end
  end

  resources :usage_logs, only: %i[show edit update] do
    member do
      get :edit_discontinued_reason
      patch :update_discontinued_reason
    end

    collection do
      get :reviews
    end
  end
end
