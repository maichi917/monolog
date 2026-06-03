class Category < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :nullify

  validates :name, presence: true,
                   length: { maximum: 20 },
                   uniqueness: { scope: :user_id }
end
