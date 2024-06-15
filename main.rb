require 'net/http'
require 'thread'
require 'nokogiri'
require 'optparse'
require 'uri'

# Not:
# Program şuan için sadece "HTTP" türünde Proxy desteklemektedir.
# Proxy listesi IP:PORT şeklinde olmalıdır.

class DorkDevSecOps
  def initialize
    @params = {
      proxy_list: nil,
      dork_list: nil,
      output: 'output.txt',
      timeout: 3,

      proxy_data: Hash.new,
      dork_data: Array.new,
      threads: Array.new
    }

    @headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/600.8.9 (KHTML, like Gecko) Version/8.0.8 Safari/600.8.9"
    }

    @cookies = {

    }
  end

  def http_requester(dorks = "", proxies = "")
    @params[:dork_data].each do |dork_query|
      success = false
      @params[:proxy_data].each do |proxy_ip, proxy_port|
        break if success

        begin
          uri = URI.parse("https://google.com/?q=#{URI.encode_www_form_component(dork_query)}")

          proxy = Net::HTTP.Proxy(proxy_ip, proxy_port).new(uri.host, uri.port)
          proxy.use_ssl = false

          proxy.open_timeout = @params[:timeout]
          proxy.read_timeout = @params[:timeout]

          request = Net::HTTP::Get.new(uri)

          response = proxy.request(request)

          if response
            if captcha_check(response.body)
              STDOUT.puts("#{proxy_ip}:#{proxy_port} -> Captcha Bulundu".red)
              STDOUT.puts("#{proxy_ip}:#{proxy_port} -> #{response.code} - #{dork_query}".red)
            elsif (200 <= response.code.to_i && response.code.to_i < 300)
              STDOUT.puts("#{proxy_ip}:#{proxy_port} -> #{response.code} - #{dork_query}".green)
              check_and_save(response.body)
              success = true
              break
            else
              STDOUT.puts("#{proxy_ip}:#{proxy_port} -> #{response.code} - #{dork_query}".red)
            end
          end
        rescue Exception => error
          STDERR.puts("Hata: #{proxy_ip}:#{proxy_port} #{error}".red)
        rescue Net::OpenTimeout, Net::ReadTimeout
          STDERR.puts("Zaman Aşımı: #{proxy_ip}:#{proxy_port}".red)
        end
      end
    end
  end

  def check_and_save(output)
    doc = Nokogiri::HTML(output)

      File.open(@params[:output], "a") do |fileman|
        doc.css('a').each do |a|
          href = a['href']

          if href && href.start_with?('/url?q=')
            decoded_url = href.split('&').first.gsub('/url?q=', '')
            url = URI.decode_www_form_component(decoded_url)
            fileman.puts(url)
          end
        end
      end
  end

  def captcha_check(body)
    return body.include?("recaptcha")
  end

  def print_help
    help_text = <<-'HELP_TEXT'
Parametreler:
  -p, --proxy-list PROXY_LIST: Proxy listesi tanımlamak için kullanılır.
  -d, --dork-list DORK_LIST: Dork listesi tanımlamak için kullanılır.
  -t, --timeout TIMEOUT: İsteklere zaman aşımı vermek için kullanılır.

  HELP_TEXT

    STDOUT.puts(help_text.blue)
  end

  def option_parser
    begin
      OptionParser.new do |opts|
        opts.on("-p", "--proxy-list PROXY_LIST", String, "Proxy listesi tanımlamak için kullanılır.") do |proxy_list|
          if File.exist?(proxy_list)
            @params[:proxy_list] = proxy_list
          else
            STDERR.puts("Hata: Belirtilen proxy listesi #{proxy_list} bulunamadı!".red)
            exit(1)
          end
        end

        opts.on("-c", "--cores", "İşlem parçacıklarını tanımlamak için kullanılır.") do |cores|
          @params[:cores] = cores
        end

        opts.on("-d", "--dork-list DORK_LIST", String, "Dork listesi tanımlamak için kullanılır.") do |dork_list|
          if File.exist?(dork_list)
            @params[:dork_list] = dork_list
          else
            STDERR.puts("Hata: Belirtilen dork listesi #{dork_list} bulunamadı!".red)
            exit(1)
          end
        end

        opts.on("-a", "--add", String, "Dorkların sonuna metin eklemesi yapmak için kullanılır.") do |add_to_dork|
          @params[:add_to_dork] = add_to_dork
        end

        opts.on("-h", "--help", "Yardım menüsünü ekrana yazdırır.") do
          print_help
          exit(0)
        end
      end.parse!
    rescue Exception => error
      STDERR.puts("Hata: #{error.class}:#{error.message}".red)
      exit!
    end
  end

  def proxy_loader
    proxy_data_lines = File.readlines(@params[:proxy_list]).uniq

    proxy_data_lines.each do |line|
      begin
        proxy_ip, proxy_port = line.split(":")
        @params[:proxy_data][proxy_ip.strip] = proxy_port.to_i if proxy_ip and proxy_port
      rescue Exception => error
        STDERR.puts("Hata: #{error.class}:#{error.message}".red)
        next
      end
    end
  end

  def dork_loader
    dork_data_lines = File.readlines(@params[:dork_list]).uniq

    dork_data_lines.each do |dork|
      @params[:dork_data].append(dork)
    end
  end

  def display_params
    params_text = <<-"PARAMS"
Atanmış Parametreler:
  Dork Listesi: #{@params[:dork_list]}
  Proxy Listesi: #{@params[:proxy_list]}
    PARAMS

    puts params_text.blue
  end

  def main
    begin
      option_parser

      if @params[:dork_list].nil? || @params[:proxy_list].nil?
        print_help
        exit!
      end

      proxy_loader
      dork_loader
      display_params

      http_requester
    rescue Interrupt

    end
  end
end

class String
  def red
    "\e[31m#{self}\e[0m"
  end

  def green
    "\e[32m#{self}\e[0m"
  end

  def yellow
    "\e[33m#{self}\e[0m"
  end

  def blue
    "\e[34m#{self}\e[0m"
  end

  def magenta
    "\e[35m#{self}\e[0m"
  end
end

dorkscan = DorkDevSecOps.new
dorkscan.main
