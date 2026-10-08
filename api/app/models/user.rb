class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  normalizes :email_address, with: ->(email_address) { email_address.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
end
