require 'net/smtp'
require 'net/imap'
require 'net/ssh'
require 'socket'
require 'whirly'
require 'logger'
require 'yaml'

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

module Crashable
  include Loggable
  include Waitable
  def try(times)
    retries ||= 0
    yield
  rescue Exception => e
    logger.error(self) { e }
    wait(1.seconds, 'A problem has occurred. Please wait.')
    retries += 1
    retries < times ? retry : (raise e)
  end
end


class Integer
  def seconds
    self
  end

  def minutes
    self * 60
  end

  def hours
    minutes * 60
  end

  def days
    hours * 24
  end
end

class Mailer
  include Loggable
  include Crashable
  include Waitable

  def initialize(mail_account, mail_server, routine_receivers)
    self.sender_mail_address = mail_account['email_address']
    self.sender_mail_password = mail_account['password']
    self.sender_provider_smtp_domain = mail_server['smtp_domain']
    self.sender_provider_smtp_portnumber = mail_server['smtp_port'].to_i
    self.sender_provider_imap_domain = mail_server['imap_domain']
    self.sender_provider_imap_portnumber = mail_server['imap_port'].to_i
    self.routine_receivers = routine_receivers['email_addresses'].split(',')
  end

  def send_to_all(tank_type, text)
    login_smtp
    routine_receivers.each do |receiver|
      send_to(receiver, tank_type, text)
    end
    logout_smtp
  end

  def send_to(receiver, tank_type, text)
    wait(3.seconds, "send message to #{receiver}..")
    message = self.message(sender_mail_address, receiver, tank_type, text)
    smtp = service
    smtp.send_message(message, sender_mail_address, receiver)
  end

  def login_smtp
    try(3) do
      self.service = Net::SMTP.start(sender_provider_smtp_domain, sender_provider_smtp_portnumber, 'localhost',
                                     sender_mail_address, sender_mail_password, :plain)
    end
  end

  def logout_smtp
    service.finish
  end

  def login_imap
    connecting_imap
    authenticate_imap
    logger.info('Mailer') { 'Login in to IMAP service successful' }
  end

  def logout_imap
    service.disconnect
  end

  def check_mailbox
    requests = {}
    imap = service
    imap.select('DataRequests') # folder in mail account

    messages = imap.search(['ALL']).each do |message_id|
      sender = fetch_sender(imap, message_id)
      requests[sender] = fetch_subject(imap, message_id)
    end

    delete_requests(messages, imap) unless requests.empty?
    requests
  end

  private

  attr_accessor :sender_mail_address, :sender_mail_password, :sender_provider_smtp_domain,
                :sender_provider_smtp_portnumber, :sender_provider_imap_domain, :sender_provider_imap_portnumber, :routine_receivers, :service

  def delete_requests(messages, imap)
    messages.each { |message_id| imap.store(message_id, '+FLAGS', [:Deleted]) } # add delete flag to messages
    imap.expunge # deletes all messages with :delete flag
  end

  def fetch_sender(imap, message_id)
    envelope = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
    adress_mailbox = envelope.sender[0].mailbox
    adress_host = envelope.sender[0].host
    "#{adress_mailbox}@#{adress_host}"
  end

  def fetch_subject(imap, message_id)
    envelope = imap.fetch(message_id, 'BODY[HEADER.FIELDS (SUBJECT)]')
    envelope[0].attr['BODY[HEADER.FIELDS (SUBJECT)]'][9..-5] # get subject string
  end

  def connecting_imap
    try(3) do
      self.service = Net::IMAP.new(sender_provider_imap_domain, port: sender_provider_imap_portnumber, ssl: true)
    end
  end

  def authenticate_imap
    try(3) do
      service.authenticate('LOGIN', sender_mail_address, sender_mail_password)
    end
  end

  def message(sender_mail_address, receiver, tank_type, text)
    <<~MESSAGE_END
      From: #{tank_type} <#{sender_mail_address}>
      To: VIP <#{receiver}>
      Subject: Level of #{tank_type}

      #{text}
    MESSAGE_END
  end

end

class Sensor
  include Loggable
  include Crashable

  def initialize(ssh_session_data)
    self.ip_adress = ssh_session_data['ip_address']
    self.pi_username = ssh_session_data['username']
    self.pi_password = ssh_session_data['password']
    self.path_to_script = ssh_session_data['script_path']
  end

  def get_data
    result = ''
    try(2) do
      Net::SSH.start(ip_adress, pi_username, password: pi_password) do |ssh|
        result = ssh.exec!(path_to_script)
      end
    end
    result.delete("\n").to_i
  end

  private

  attr_accessor :ip_adress, :pi_username, :pi_password, :path_to_script
end

# Todo: extend Integerclass with seconds, hours, days methods

class InvalidDistanceError < StandardError
  def initialize(msg = 'Sensor measurement data is invalid. Check if sensor is mounted correctly and is not blocked..')
    super
  end
end

class DistanceInfomationScript
  include Loggable
  include Waitable

  def initialize(interval, parameters)
    @mailshot_interval = interval.to_i.days
    @mailer = Mailer.new(parameters['MAIL_ACCOUNT'], parameters['MAIL_SERVER'], parameters['RECIEVERS'])
    @sensor = Sensor.new(parameters['SSH_SESSION_DATA_PI_SENSOR'])
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
  attr_accessor :mailer, :sensor

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
      wait(check_mailbox_interval, "Listening for requests every #{check_mailbox_interval} seconds..")
    end
    mailer.logout_imap
  end

  def select_text(fill_level)
    if fill_level > 80
      "Warning!!! The tank is #{fill_level}% full.\n\nPlease inform the President! Number: 030 234324"
    elsif interval_message
      "Update-Routine. The tank is #{fill_level}% full."
    else
      "The tank is #{fill_level}% full."
    end
  end

  def get_fill_level
    new_distance = 20#sensor.get_data
    raise InvalidDistanceError if new_distance > tank_height

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
