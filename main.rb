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

# Todo: extend Integerclass with seconds, hours, days methods

class DistanceInfomationScript
  include Loggable
  include Waitable

  def initialize(interval, parameters)
    @mailshot_interval = interval.to_i.days
    @mailer = Mailer.new(parameters)
    @tank_type = parameters['TANKDATA']['type']
    @tank_height = parameters['TANKDATA']['height']
    @check_level_interval = parameters['SCRIPT_INTERVAL']['check_level'].to_i.days
    @check_mailbox_interval = parameters['SCRIPT_INTERVAL']['check_mailbox'].to_i.seconds
  end

  def execute
    logger.info('DistanceInformationScript') { 'Programme has started.' }
    loop do
      fill_level = get_fill_level
      wait(3.seconds, 'Sending interval message..')
      mailer.send_to_all
      update_loop
    end
  end

  private 
  attr_reader :mailshot_interval, :tank_height, :tank_type, :check_level_interval, :check_mailbox_interval
  attr_accessor :mailer

  def update_loop
    time_end = Time.now + mailshot_interval
    while Time.now < time_end
      listen_for_data_request
      fill_level = get_fill_level
      mailer.send_to_all(tank_type, select_text(fill_level)) if fill_level > 80 # percent
    end
  end

  def listen_for_data_request
    time_end = Time.now + check_level_interval
    mailer.login_imap
    while Time.now < time_end
      requests = mailer.check_mailbox
      send_responses(requests)
      wait(check_mailbox_interval, 'Listening for requests every 30 seconds..')
    end
    mailer.logout_imap
  end

  def select_text(fill_level)
    
  end

  def get_fill_level
    new_distance = 20#sensor.get_data
    # raise InvalidDistanceError if new_distance > tank_height

    convert_distance_to_percent(new_distance, tank_height)
  end

  def send_responses(requests)
    fill_level = get_fill_level
    requests.each do |sender, subject|
      mailer.login_smtp
      if subject == request_subject
        wait(2.seconds, "Recieved request from #{sender}..")
        mailer.send_to(sender, tank_type, select_text(fill_level))
      end
      mailer.logout_smtp
      mailer.login_imap
    end
  end

  def convert_distance_to_percent(distance, tank_height)
    100 - (distance / (tank_height / 100))
  end

end

parameters = YAML.load_file('mailing_config.yml')
DistanceInfomationScript.new(parameters['SCRIPT_INTERVAL']['mailshot'], parameters).execute
