require 'logger'
require 'whirly'

module Loggable
  def logger
    Loggable.logger
  end

  def self.logger
    @logger ||= Logger.new('log/mailing_log.log')
  end
end

module Waitable
  include Loggable
  def wait(time, message)
    logger.info('Waits') { message }
    Whirly.configure(spinner: 'bouncingBall')
    Whirly.start do
      Whirly.status = message
      sleep(time)
    end
    system 'clear'
  end
end

class Mailer
  include Loggable
  include Waitable

  def initialize(parameters)
  end

  def send_to_all
  end

  def send_to
  end

  def login_smtp
  end

  def logout_smtp
  end

  def login_imap
  end

  def logout_imap
  end

  def check_mailbox
  end

end


class DistanceInfomationScript
  include Loggable
  include Waitable

  def initialize(interval, parameters)
  end

  def execute
    
  end

end

parameters = YAML.load_file('mailing_config.yml')
DistanceInfomationScript.new(7.days, parameters).execute
