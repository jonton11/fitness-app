module Api
  module V1
    class SessionsController < ApplicationController
      allow_unauthenticated_access only: :create

      def show
        render_resource(:user, Current.user, serializer: Api::V1::UserSerializer)
      end

      def create
        user = User.authenticate_by(
          email_address: session_params[:email_address].to_s.strip.downcase,
          password: session_params[:password]
        )

        if user
          start_session_for(user)
          render_resource(:user, user, serializer: Api::V1::UserSerializer, status: :created)
        else
          render_api_error(
            field: "email_address",
            code: ERROR_CODE_INVALID,
            message: "Email or password is incorrect",
            status: :unauthorized
          )
        end
      end

      def destroy
        end_current_session
        head :no_content
      end

      private

      def session_params
        params.require(:session).permit(:email_address, :password)
      end
    end
  end
end
