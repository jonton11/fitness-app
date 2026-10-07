class ApiToken < ApplicationRecord
  TOKEN_PREFIX = "fitness_"

  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :token_digest, presence: true
  validates :token_digest, uniqueness: true

  class << self
    def issue!(user:, name:)
      token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
      record = user.api_tokens.find_or_initialize_by(name:)
      record.token_digest = digest(token)
      record.save!
      [ record, token ]
    end

    def authenticate(token)
      return if token.blank?

      find_by(token_digest: digest(token))&.user
    end

    private

    def digest(token)
      Digest::SHA256.hexdigest(token)
    end
  end
end
