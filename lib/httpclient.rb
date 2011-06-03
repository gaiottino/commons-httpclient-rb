# encoding: utf-8

require 'java'

module Apache
  require 'ext/commons-codec'
  require 'ext/commons-logging'
  require 'ext/commons-httpclient-3.1'
  
  import org.apache.commons.httpclient.HttpStatus
  import org.apache.commons.httpclient.HttpClient
  import org.apache.commons.httpclient.methods.GetMethod
end

module Commons
  class RequestTimeout < Exception; end
  
  class HttpStatus < Apache::HttpStatus; end
  
  class HttpClient
    
    USER_AGENT = "Mozilla/5.0 (compatible; +http://www.richmetrics.com/bot.html)"
  
    def initialize(options = {})
      @client = Apache::HttpClient.new
      @timeout = options[:timeout]
      @redirect_limit = options[:redirect_limit]
      
      if @timeout
        @client.params.so_timeout = @timeout
        @client.http_connection_manager.params.connection_timeout = @timeout
      end
    end
    
    def get(url, headers = {})
      request(Apache::GetMethod, url, @redirect_limit)
    end
    
  private
  
    def request(request_method, url, redirect_limit = nil)
      method = request_method.new(url)
      method.follow_redirects = false
      method.add_request_header("User-Agent", USER_AGENT)

      begin
        status = @client.execute_method(method)
        result = Result.new

        case status
        when HttpStatus::SC_MULTIPLE_CHOICES,
             HttpStatus::SC_MOVED_PERMANENTLY, 
             HttpStatus::SC_MOVED_TEMPORARILY, 
             HttpStatus::SC_SEE_OTHER, 
             HttpStatus::SC_NOT_MODIFIED, 
             HttpStatus::SC_USE_PROXY, 
             HttpStatus::SC_TEMPORARY_REDIRECT
          redirect_limit -= 1 if redirect_limit
          unless redirect_limit && redirect_limit <= 0
            location = method.get_response_header('location')
            return request(request_method, location.value, redirect_limit) if location
          end
          result.status = HttpStatus::SC_NOT_FOUND
          return result
        when HttpStatus::SC_OK
          result.status = status
          result.content = method.response_body_as_stream.to_io.read
        
          content_type = method.get_response_header('Content-Type')
          result.content_type = content_type ? content_type.value : 'unknown'
        else
          result.status = status
        end
        
        result
      rescue java.net.SocketTimeoutException => e
        raise RequestTimeout.new(e)
      ensure
        method.release_connection
      end
    end
  end
  
  class Result
    attr_accessor :status, :content_type, :content
  end
end
