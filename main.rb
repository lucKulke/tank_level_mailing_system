require 'logger'

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
