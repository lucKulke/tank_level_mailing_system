# Tank Level information system

## Description

The computer (raspberry pi) informs you via e-mail about the current fill level of a tank.

## Requirements

1. ruby version: 2.7.5
2. config file: Yaml

config file:
```yml
SCRIPT_INTERVAL:
  mailshot: "7" #days
  check_level: "1" #days 
  check_mailbox: "30" #seconds
MAIL_ACCOUNT: 
  email_address: "example@mail.com"
  password: "password123"
MAIL_SERVER:
  smtp_domain: "example.domain.net"
  smtp_port: "587"
  imap_domain: "example.domain.net"
  imap_port: "993"
RECIEVERS:
  email_addresses: "example1@mail.com,example2@mail.com" # seperate addresses with ',' 
  request_subject: "-lr" # subject for datarequest mail
SSH_SESSION_DATA_PI_SENSOR:
  ip_address: "255.255.255.255"
  username: "pi"
  password: "password123"
  script_path: "/home/pi/distance_sensor.py"
TANK_DATA:
  height: "500" # cm
  type: "Wastewatertank"

```

## Run script

1. install ruby 2.7.5 (probably also works with newer ruby versions)
2. install bundler: ```gem install bundler```
3. Create a yaml config file with login data, etc.
4. rund script with: ```bundler exec ruby mailing_system```