module Listerine
  class Mailer
    class << self
      def mail(to, subject, body)
        Listerine::Logger.warn("Sending mail to #{to}. Subject: #{subject}")
        Pony.mail(:to => to, :from => Listerine::Options.instance.from,
                  :subject => subject, :body => body)
      end
    end
  end
end
