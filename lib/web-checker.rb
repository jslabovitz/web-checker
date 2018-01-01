require 'addressable'
require 'nokogiri'
require 'path'
require 'tidy_ffi'

class WebChecker

  Version = '0.1'
  IgnoreErrors = %Q{
    <table> lacks "summary" attribute
    <img> lacks "alt" attribute
    <form> proprietary attribute "novalidate"
    <input> attribute "type" has invalid value "email"
    <input> attribute "tabindex" has invalid value "-1"
    <input> proprietary attribute "border"
    trimming empty <p>
    <iframe> proprietary attribute "allowfullscreen"
  }.split(/\n/).map(&:strip)
  LinkElementsXPath = '//@href | //@src'
  SchemasDir = Path.new(__FILE__).dirname / 'schemas'
  Schemas = {
    'feed' => SchemasDir / 'atom.xsd',
    'urlset' => SchemasDir / 'sitemap.xsd',
  }

  class Error < Exception; end

  def initialize(site_uri:, site_dir:)
    @site_uri = Addressable::URI.parse(site_uri)
    @site_dir = Path.new(site_dir)
    @schemas = {}
    @visited = {}
  end

  def check
    # get/parse robots
    # get/parse sitemap
    check_uri(@site_uri)
  end

  def check_uri(uri)
    uri = Addressable::URI.parse(uri)
    return unless local_uri?(uri)
    return if seen_uri?(uri)
    ;;warn "CHECKING: #{uri}"
    response = HTTP::Get.new(uri.path)
    ;;pp(uri.path => response)
    @visited[uri] = true
    case response.status
    when 200...300
      case (type = response.headers['Content-Type'])
      when 'text/html'
        check_html(uri, response.body)
      when 'text/css'
        check_css(uri, response.body)
      when 'application/xml'
        check_xml(uri, response.body)
      else
        ;;warn "SKIPPING: #{uri} (#{type})"
      end
    when 300...400
      redirect_uri = Addressable::URI.parse(response.headers['Location'])
      check_uri(uri + redirect_uri)
    when 404
      raise Error, "URI not found: #{uri}"
    else
      raise Error, "Bad status: #{response.inspect}"
    end
  end

  def check_html(uri, html)
    tidy = TidyFFI::Tidy.new(html, char_encoding: 'UTF8')
    unless (errors = tidy_errors(tidy)).empty?
      warn "#{html_file} has invalid HTML"
      errors.each do |error|
        warn "\t#{error[:msg]}"
      end
      raise Error, "HTML parsing failed (via Tidy)"
    end
    html_doc = Nokogiri::HTML::Document.parse(html) { |config| config.strict }
    unless html_doc.errors.empty?
      show_errors(html_doc.errors)
      raise Error, "HTML parsing failed (via Nokogiri)"
    end
    html_doc.xpath(LinkElementsXPath).each { |e| check_uri(uri + e.value) }
  end

  def tidy_errors(tidy)
    return [] unless tidy.errors
    tidy.errors.split(/\n/).map { |str|
      str =~ /^line (\d+) column (\d+) - (.*?): (.*)$/ or raise "Can't parse error: #{str.inspect}"
      {
        msg: str,
        line: $1.to_i,
        column: $2.to_i,
        type: $3.downcase.to_sym,
        error: $4.strip,
      }
    }.reject { |e|
      IgnoreErrors.include?(e[:error])
    }
  end

  def check_xml(uri, xml)
    xml_doc = Nokogiri::XML::Document.parse(xml) { |config| config.strict }
    unless xml_doc.errors.empty?
      show_errors(xml_doc.errors)
      raise Error, "XML parsing failed"
    end
    root_name = xml_doc.root.name
    schema = find_schema(root_name) or raise Error, "Unknown schema: #{root_name}"
    validation_errors = schema.validate(xml_doc)
    unless validation_errors.empty?
      show_errors(validation_errors)
      raise Error, "XML validation failed"
    end
    xml_doc.xpath(LinkElementsXPath).each { |e| check_uri(uri + e.value) }
  end

  def show_errors(errors)
    errors.each do |error|
      warn "#{error} [line #{error.line}, column #{error.column}]"
    end
  end

  def check_css(uri, css)
    css.gsub(/\burl\(\s*["'](.*?)["']\s*\)/) do
      check_uri(uri + $1)
    end
  end

  def find_schema(name)
    schema_file = Schemas[name] or return nil
    unless (schema = @schemas[schema_file])
      ;;warn "loading schema for <#{name}> element"
      @schemas[schema_file] = schema = Nokogiri::XML::Schema(schema_file.open)
    end
    schema
  end

  def local_uri?
    (!uri.scheme && !uri.host) ||
      (uri.scheme == @site_uri.scheme && uri.host == @site_uri.host && uri.port == @site_uri.port)
  end

  def seen?
    @visited[uri]
  end

  def report
    unless @files.empty?
      puts "\t" + "unreferenced files:"
      @files.sort.each do |path|
        puts "\t\t" + path.to_s
      end
    end
  end

end