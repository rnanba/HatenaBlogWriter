# coding: utf-8
# HBW::Client
# coding: utf-8

require 'atomutil'
require 'yaml'
require 'digest/sha1'

Encoding.default_external = Encoding::UTF_8

module HBW
  DATA_DIR = "data"

  class TextContent < Atom::Content
    def body=(value)
      @elem.add_text value
      self.type = 'text'
    end
  end

  class EntryMetaData
    def self.data_filename(entry_filename)
      "#{DATA_DIR}/#{entry_filename}.dat"
    end
    
    def self.entry_filename(data_filename)
      if /^(.+)\.dat$/.match(data_filename)
        $1
      else
        nil
      end
    end
    
    def self.listData()
      return Dir.glob("#{DATA_DIR}/*.dat").map() { |data_filename|
        self.new(self.entry_filename(File.basename(data_filename)))
      }
    end
    
    def initialize(entry_filename)
      unless File.exists?(entry_filename)
        raise "ERROR: entry file not found."
      end
      @entry_filename = entry_filename
      @data_filename = EntryMetaData.data_filename(entry_filename)
      if File.exists?(@data_filename)
        @data = YAML.load_file(@data_filename)
      else
        @data = {}
      end
    end

    def entry_filename
      @entry_filename
    end

    def url
      @date['url']
    end
    
    def location
      @data['location']
    end

    def mtime
      @data['mtime']
    end
    
    def edited
      @data['edited']
    end

    def sha1
      @data['sha1']
    end
    
    def set_posted(location, edited, sha1)
      @data['location'] = location
      set_updated(edited, sha1)
    end
    
    def set_updated(edited, sha1)
      @data['edited'] = edited
      @data['sha1'] = sha1
      @data['mtime'] = File.mtime(@entry_filename)
    end

    def set_sha1(sha1)
      @data['sha1'] = sha1
    end

    def set_url(url)
      @data['url'] = url
    end

    def fix_mtime
      @data['mtime'] = File.mtime(@entry_filename)
    end

    def save
      File.open(@data_filename, "w") { |f|
        YAML.dump(@data, f)
      }
    end

    def delete
      begin
        File.delete(@data_filename)
      rescue
        puts $!
      end
    end

    def to_s
      YAML.dump(@data)
    end
  end
  
  class EntryFile
    def initialize(filename_or_entry=nil)
      @header = {
        title: "",
        category: [],
        draft: 'no',
      }
      @content = ""
      @location = nil
      @delete = false
      if (filename_or_entry == nil) then
        # nop
      elsif (filename_or_entry.is_a?(Atom::Entry))
        @filename = nil
        parse_entry(filename_or_entry)
      elsif (filename_or_entry.is_a?(String))
        @filename = filename_or_entry
        if File.exists?(@filename)
          # @header[:date] = File.mtime(filename)
          parse_file()
        else
          @header[:date] = Time.now
        end
      else
        raise ArgumentError, "arg is not a String or Atom::Entry"
      end
    end

    def set_title(title)
      @header[:title] = title
    end
    
    def parse_file
      in_header = true
      content_lines = []
      File.open(@filename, "r").each_line { |line|
        line = line.chomp
        if in_header 
          m = /^(?<key>\w+):\s*(?<value>.*)$/.match(line)
          if m == nil
            in_header = false
            content_lines.push(line)
            next
          end
          key = m[:key].to_sym
          value = m[:value]
          if key 
            if key == :date
              value = Time.parse(value)
            elsif key == :category
              value = value.strip().split(/\s*,\s*/)
            end
            if @header[key] != nil || key == :date
              @header[key] = value
            elsif key == :delete
              @delete = (/^yes$/.match(value) != nil)
            else
              abort "ERROR: 不正なヘッダ属性: '#{key}'"
            end
          else
            in_header = false
          end
        else
          content_lines.push(line)
        end
      }
      @content = normalize_content(content_lines)
    end

    def normalize_content(lines)
      first = lines.index {|line| line != ""}
      last = lines.rindex {|line| line != ""}
      return (first && last) ? lines[first..last].join("\n") : ""
    end
    
    def parse_entry(entry, empty_date=false)
      @header = {
        title: entry.title,
        category: entry.categories.map { |c| c.term },
        draft: entry.control.draft
      }
      @header[:date] = Time.parse(entry.updated.to_s) if (!empty_date)
      if entry.content.body then
        @content = normalize_content(entry.content.body.lines(chomp:true))
      else
        @content = ""
      end
    end

    def date
      @header[:date]
    end
    
    def sha1
      Digest::SHA1.hexdigest(to_array.join("\n"))
    end

    def delete?
      return @delete
    end
    
    def entry
      entry = Atom::Entry.new
      entry.title = @header[:title]
      if @header[:date]
        entry.updated = @header[:date]
      end
      @header[:category].each { |cat|
        entry.add_category(Atom::Category.new(term: cat.strip()))
      }
      entry.content = HBW::TextContent.new({:body => @content})
      entry.add_control(Atom::Control.new(draft: @header[:draft]))
      return entry
    end

    def save
      save_as(@filename)
    end
    
    def save_as(filename)
      if File.exists?(filename)
        abort "ERROR: ファイルが存在します。"
      end
      File.open(filename, "w") { |f|
        to_array.each { |line|
          f.puts(line)
        }
      }
    end

    def to_array
      a = [
        "title: #{@header[:title]}",
        "date: #{@header[:date]}",
        "category: #{@header[:category].join(', ')}",
        "draft: #{@header[:draft]}",
        "",
        @content
      ]
      if @delete
        a.unshift("delete: yes")
      end
      return a
    end

    def to_s
      to_array.join("\n")
    end
  end
  
  class Client
    def initialize
      config = YAML.load_file("config.yml")
      @id = config['id']
      @blog_domain = config['blog_domain']
      @post_uri = "https://blog.hatena.ne.jp/#{@id}/#{@blog_domain}/atom/entry"
      auth = Atompub::Auth::Wsse.new(username: @id,
                                     password: config['api_key'])
      @client = Atompub::Client.new(auth: auth)
      @service_uri = "https://blog.hatena.ne.jp/#{@id}/#{@blog_domain}/atom"
      @service = nil
    end

    def ensure_data_dir
      unless File.exists?(DATA_DIR)
        Dir.mkdir(DATA_DIR)
        # puts "OK: データディレクトリを作成しました。"
      end
    end

    def ensure_get_service(reload=false)
      if reload || @service == nil
        @service = @client.get_service(@service_uri)
      end
    end
    
    def set_username(entry)
      author = Atom::Author.new
      author.name = @id
      entry.author = author
    end
    
    def post(filename)
      ensure_data_dir()
      entry_file = EntryFile.new(filename)
      if entry_file.delete?
        puts "INFO: #{filename}: 削除済みエントリです。"
        return
      end
      data_file = EntryMetaData.new(filename)
      if data_file.location
        abort "ERROR: #{filename}: 投稿済のエントリファイルです。投稿を中止しました。"
      end
      entry = entry_file.entry
      set_username(entry)
      ensure_data_dir()
      ensure_get_service()
      location = @client.create_entry(@post_uri, entry);
      puts "OK: #{filename}: エントリを投稿しました。"
      data_file.set_posted(location,
                           Time.parse(@client.rc.edited.text), entry_file.sha1)
      data_file.save
      #puts "OK: 投稿データファイルを作成しました。"
    end

    def update(filename)
      ensure_data_dir()
      entry_file = EntryFile.new(filename)
      data_file = EntryMetaData.new(filename)
      if entry_file.delete?
        begin
          delete(data_file)
          puts "OK: #{filename}: エントリを削除しました。"
        rescue => e
          puts "NG: #{filename}: エントリの削除に失敗しました。(#{e})"
        end
        return
      end
      unless data_file.location
        abort "ERROR: #{filename}: 未投稿のエントリファイルです。更新を中止しました。"
      end
      entry = entry_file.entry
      set_username(entry)
      ensure_get_service()
      @client.update_entry(data_file.location, entry);
      puts "OK: #{filename}: エントリを更新しました。"
      posted_entry = @client.rc.is_a?(Atom::Entry) ? @client.rc : Atom::Entry.new(:stream => @client.rc)
      data_file.set_updated(Time.parse(posted_entry.edited.text), entry_file.sha1)
      data_file.save
      #puts "OK: 投稿データファイルを更新しました。"
    end

    def delete(data_file)
      unless data_file.location
        # 削除済み
        return
      end
      ensure_get_service()
      @client.delete_entry(data_file.location)
      data_file.delete()
    end
  end
end
