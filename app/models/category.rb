class Category < ApplicationRecord
  belongs_to :user

  validates :name, presence: true,
                   length: { maximum: 20 },
                   uniqueness: { scope: :user_id }
end
