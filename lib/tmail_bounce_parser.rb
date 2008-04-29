# This is a parser based on the "Handling Bounced Email" section of the "Rails Recipes" book.
# Not all e-mail servers follow RFC-1892 perfectly (i.e. some don't include the original message, 
# some show the original message header inline rather than as a separate part of content, etc.)
# 
# This module is designed to handle specific mail servers which don't support RFC-1892 properly
module TmailBounceParser

  class BouncedDelivery
    attr_accessor :status_info, :original_message_id, :original_sender, :original_recipient, :original_subject, :handling_server
    def self.from_email(email)
      returning(bounce = self.new) do

        if (email['subject'].to_s =~ /not listed in Domino Directory/)
          bounce.handling_server = "DOMINO"
        elsif (email['subject'].to_s =~ /Mail delivery failed: returning message to sender/)
          bounce.handling_server = "EXIM"
        else
          bounce.handling_server = "STANDARD"
        end

        # Domino mail servers munge the "original message id" to something completely different
        # from the real original message-id. Therefore, only the original sender, recipients, subject, 
        # etc. can be retrieved.
        if bounce.handling_server == "DOMINO"
          status_part = email.parts.detect do |part|
            part.content_type == "message/delivery-status"
          end
          statuses = status_part.body.gsub("\n ","").split(/\n/)
          bounce.status_info = statuses.inject({}) do |hash,line|
            key,value = line.split(/:/,2)
            hash[key] = value.strip rescue nil
            hash
          end
          bounce.original_recipient = status_part.to_s[/^Final-Recipient:.*$/].gsub("Final-Recipient: ","").gsub("rfc822;","").strip
          original_message_part = email.parts.detect do |part|
            part.content_type == "message/rfc822"
          end
          bounce.original_subject = original_message_part.to_s[/^Subject:.*$/].gsub("Subject:","").strip
        end
        
        # Exim mail servers don't use the report/message-status and mail/rfc222 parts. Rather,
        # they include the original message header information inline.
        if bounce.handling_server == "EXIM"
          
        end
        
        # This is to cover all other mail servers that properly follow the message/delivery-status and 
        # message/rfc822 parts
        if bounce.handling_server == "STANDARD"
          status_part = email.parts.detect do |part|
            part.content_type == "message/delivery-status"
          end
          unless status_part.nil?
            statuses = status_part.body.gsub("\n ","").split(/\n/)
            bounce.status_info = statuses.inject({}) do |hash,line|
              key,value = line.split(/:/,2)
              hash[key] = value.strip rescue nil
              hash
            end
            original_message_part = email.parts.detect do |part|
              part.content_type == "message/rfc822"
            end
            unless original_message_part.nil?
              parsed_msg = TMail::Mail.parse(original_message_part.body)
              bounce.original_message_id = parsed_msg.message_id
            end
          end
        end
        # //////////////////////////

      end
    end
    def status
      case status_info['Status']
      when /^5/
        'Failure'
      when /^4/
        'Temporary Failure'
      when /^2/
        'Success'
      end
    end
  end
  
  def undeliverable_info
    BouncedDelivery.from_email(self)
  end
end