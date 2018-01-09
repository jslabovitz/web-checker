require 'addressable'
require 'http'
require 'nokogiri'
require 'nokogumbo'
require 'path'

class WebChecker

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
  SchemasDir = Path.new(__FILE__).dirname / 'web-checker' / 'schemas'
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
    uri.normalize!
    return unless local?(uri) && !seen?(uri)
    # ;;warn "CHECKING: #{uri}"
    response = HTTP.get(uri)
    # ;;pp(response: response)
    @visited[uri] = true
    case response.code
    when 200...300
      body = response.body.to_s
      # ;;pp(body: body)
      case (type = response.headers['Content-Type'])
      when 'text/html'
        check_html(uri, body)
      when 'text/css'
        check_css(uri, body)
      when 'application/xml', 'text/xml'
        check_xml(uri, body)
      when 'image/jpeg', 'image/png', 'image/gif', 'application/javascript'
        # ignore
      else
        ;;warn "skipping unknown resource type: #{uri} (#{type})"
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
    check_html_tidy(uri, html)
    check_html_nokogiri(uri, html)
  end

  def check_html_tidy(uri, html)
    tmp_file = Path.tmpfile
    tmp_file.write(html)
    errors = %x{tidy -utf8 -quiet -errors #{tmp_file} 2>&1}.split("\n")
    errors = errors.map { |str|
      # line 82 column 1 - Warning: <table> lacks "summary" attribute
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
    unless errors.empty?
      warn "#{uri} has invalid HTML"
      show_errors(errors)
      raise Error, "HTML parsing failed (via Tidy)"
    end
  end

  def check_html_nokogiri(uri, html)
    doc_class = (html =~ /<!DOCTYPE html>/i) ? Nokogiri::HTML5 : Nokogiri::HTML
    doc = doc_class.parse(html) { |config| config.strict }
    unless doc.errors.empty?
      show_errors(doc.errors)
      raise Error, "HTML parsing failed (via Nokogiri)"
    end
    doc.xpath(LinkElementsXPath).each { |e| check_uri(uri + e.value) }
  end

  def check_xml(uri, xml)
    xml_doc = Nokogiri::XML::Document.parse(xml) { |config| config.strict }
    unless xml_doc.errors.empty?
      show_errors(xml_doc.errors)
      raise Error, "XML parsing failed"
    end
    root_name = xml_doc.root.name
    schema_file = Schemas[root_name] or raise Error, "Unknown schema: #{root_name.inspect}"
    schema = (@schemas[schema_file] ||= Nokogiri::XML::Schema(schema_file.open))
    validation_errors = schema.validate(xml_doc)
    unless validation_errors.empty?
      show_errors(validation_errors)
      raise Error, "XML validation failed"
    end
    xml_doc.xpath(LinkElementsXPath).each { |e| check_uri(uri + e.value) }
  end

  def show_errors(errors)
    errors.each do |error|
      warn "#{error} [line #{error[:line]}, column #{error[:column]}]"
    end
  end

  def check_css(uri, css)
    css.gsub(/\burl\(\s*["'](.*?)["']\s*\)/) do
      check_uri(uri + $1)
    end
  end

  def local?(uri)
    (!uri.scheme && !uri.host) ||
      (uri.scheme == @site_uri.scheme && uri.host == @site_uri.host && uri.port == @site_uri.port)
  end

  def seen?(uri)
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