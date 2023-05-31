require 'logger'

module Loggable
  def logger
    Loggable.logger
  end

  def self.logger
    @logger ||= Logger.new('log/mailing_log.log')
  end
end
