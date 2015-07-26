#!/usr/bin/ruby

require 'pp'

# Data to be able to plot
# hours slept per night (6pm - 6am)
# interuptions per night (6pm - 6am)
# Feedings per day
# average length of feedings
# diapers changed (broken down by wet/dirty)
#

class BabyConnectDataParser
  require 'csv'
  require 'json'

  KNOWN_ACTIVITIES = [:bottle, :diaper, :diary, 
                      :head_size, :height, :message, 
                      :milestone, :nursing, :sleep, 
                      :sleep_start, :temperature, :weight]

  ACTIVITY_REGEXES = {}

  attr_reader :raw_data, :data

  def initialize(filename)
    raise ArgumentError, "Invalid file '#{filename}' specified." if !filename.kind_of?(String) && File.readable?(filename)
    @raw_data_filename = filename

    @raw_data = read_raw_data(@raw_data_filename)
  end

  def read_raw_data(csv_filename)
    raise ArgumentError, "Unable to read file '#{csv_filename}'" unless File.readable? csv_filename
    CSV.parse(
      File.read(csv_filename), 
      { :headers => true, :header_converters => :symbol }
    )
  end

  def categorize_data
    @categorized_data = @raw_data.reduce( Hash.new { |h, k| h[k] = [] }) do |acc, row|
      activity = row[:activity].downcase.gsub(/\s/, '_').to_sym

      parsed_record = self.send("parse_#{activity}_record", row.to_hash) rescue nil

      acc[activity].push(parsed_record || row.to_hash)
      acc
    end
  end

  def to_csv(base_filename = './baby_connect_parsed')
    puts "Exporting parsed data to CSV"
    categorize_data unless @categorized_data
    delimiter = ', '

    @categorized_data.sort.each do |activity, data|
      puts "\t Exporting parsed #{activity} data..."
      filename = "#{base_filename}_#{activity}.csv"
      
      posted_header = false

      File.open( filename, 'w' ) do |f| 
        unless posted_header
          f.puts data.first.keys.join(delimiter)
          posted_header = true
        end

        f.puts( data.map { |r| r.values.map {|x| "\"#{x}\""} * delimiter } )
      end
    end
  end

  def to_json(base_filename = './baby_connect_parsed')
    puts "Exporting parsed data to JSON"
    categorize_data unless @categorized_data

    @categorized_data.sort.each do |activity, data|
      puts "\t Exporting parsed #{activity} data..."
      filename = "#{base_filename}_#{activity}.json"
      
      File.open( filename, 'w' ) do |f| 
        f.puts @categorized_data.to_json
      end
    end
  end

  def parse
    categorize_data
    to_csv
  end

  private

  def format_date(date)
    DateTime.parse(date).strftime('%F %T')
  end

  def parse_nursing_text(text)
    interesting_bits = text.match(/Hazel nursed \((.*)\)/).captures.first

    interesting_bits.split(',').reduce( Hash.new(0) ) do |acc, side| 
      duration, side = side.split(' ')
      duration = duration.gsub('min', '').to_i

      unless side.nil?
        acc[side.to_sym] += duration
      else
        # Accounts for times when the side isn't specified. Just divy up the minutes
        acc[:right] += duration / 2.0
        acc[:left] += duration / 2.0
      end

      acc
    end
  end

  def parse_nursing_record(record)
    # Parse timestamps
    record[:start_time] = format_date(record[:start_time])
    record[:end_time] = format_date(record[:end_time])

    # Parse the text of the record to get the duration per side in minutes
    parsed_text = parse_nursing_text(record[:text])
    record[:left_side] = parsed_text[:left]
    record[:right_side] = parsed_text[:right]

    # Delete unused or derivative fields
    record.delete(:duration)
    record.delete(:extra_data)

    record
  end

  #def parse_diaper_record(record)
  #  # Parse timestamps
  #  record[:start_time] = format_date(record[:start_time])
  #  record[:end_time] = format_date(record[:end_time])

  #end

  #def parse_diaper_text(text)

  #end
end

bc_data_filename = ARGV[0]

bcdp = BabyConnectDataParser.new(bc_data_filename)

puts "Analyzing #{bc_data_filename}..."

raw_data = bcdp.read_raw_data(bc_data_filename)

categorized_data = bcdp.categorize_data
  
puts "Summary of data from '#{bc_data_filename}':"

categorized_data.sort.each do |activity, rows|
  puts "Found #{rows.size} entr#{rows.size > 1 ? 'ies':'y'} for #{activity}"
end

bcdp.to_csv

