# frozen_string_literal: true

#
# ApplicationMailer: Base mailer class
class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'
end
