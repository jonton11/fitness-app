namespace :fitness do
  desc "Provision or update the single application user"
  task provision_user: :environment do
    email_address = ENV.fetch("FITNESS_USER_EMAIL")
    password = ENV.fetch("FITNESS_USER_PASSWORD")
    user = User.find_or_initialize_by(email_address:)
    user.password = password
    user.password_confirmation = password
    user.save!

    puts "Provisioned #{user.email_address}"
  end

  desc "Issue an iOS API token for the provisioned user"
  task issue_api_token: :environment do
    email_address = ENV.fetch("FITNESS_USER_EMAIL")
    name = ENV.fetch("FITNESS_API_TOKEN_NAME", "iPhone")
    user = User.find_by!(email_address:)
    _record, token = ApiToken.issue!(user:, name:)

    puts token
  end
end
