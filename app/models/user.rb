class User < ApplicationRecord
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :items, dependent: :destroy
  has_many :usage_logs, dependent: :destroy
  has_many :categories, dependent: :destroy

  # nameは必須（重複は許可）
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, format: { with: EMAIL_FORMAT }
end
