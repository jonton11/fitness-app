module Api
  module V1
    class UserSerializer
      def initialize(user)
        @user = user
      end

      def as_json
        {
          id: user.id,
          email_address: user.email_address
        }
      end

      private

      attr_reader :user
    end
  end
end
