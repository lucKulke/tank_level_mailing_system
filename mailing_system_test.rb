# unit testing
require 'yaml'
require "minitest/autorun"

require_relative 'mailing_system'

class TestMailingSystem < Minitest::Test
  def setup
    @config = YAML.load_file('config.yml')
    @tank_level_information_system = TankLevelInformationSystem.new(@config['SCRIPT_INTERVAL']['mailshot'], @config)
    @mailer = Mailer.new(@config['MAIL_ACCOUNT'], @config['MAIL_SERVER'], @config['RECIEVERS'])
  end

  def test_mailshot
    assert_equal(true, @tank_level_information_system.send(:mailshot))
  end

  def test_convert_distance_to_percent
    assert_equal(80, @tank_level_information_system.send(:convert_distance_to_percent, 100, 500))
  end

  def test_mailer_send_to_all
    fill_level = 50#percent
    text = 'Unit test Mailer#send_to_all'
    assert_equal(true, @mailer.send_to_all(@config['TANK_DATA']['type'], text))
  end

  def test_mailer_send_to
    receiver = @config['RECIEVERS']['email_addresses'].split(',')[0]
    tank_type = @config['TANK_DATA']['type']
    text = 'Unit test Mailer#send_to'
    @mailer.login_smtp
    assert_equal(true, @mailer.send_to(receiver, tank_type, text))
    @mailer.logout_smtp
  end

  def test_mailer_login_smtp
    assert_equal(true, @mailer.login_smtp)
    @mailer.logout_smtp
  end

  def test_mailer_logout_smtp
    @mailer.login_smtp
    assert_equal(true, @mailer.logout_smtp)
  end

  def test_mailer_login_imap
    assert_equal(true, @mailer.login_imap)
    @mailer.logout_imap
  end

  def test_mailer_logout_imap
    @mailer.login_imap
    assert_equal(true, @mailer.logout_imap)
  end

  def test_mailer_check_mailbox
    @mailer.login_imap
    assert_instance_of(Hash, @mailer.check_mailbox)
    @mailer.logout_imap
  end
end