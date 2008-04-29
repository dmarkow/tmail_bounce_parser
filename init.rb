require 'tmail'
require 'tmail_bounce_parser'
TMail::Mail.send :include, TmailBounceParser
