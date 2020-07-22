#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

require_relative 'lib/unspan_all_tables'

# The Wikipedia page with a list of officeholders
class ListPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :officeholders do
    list.xpath('.//tr[td]').map { |td| fragment(td => HolderItem) }.reject(&:empty?).map(&:to_h).uniq(&:to_s)
  end

  private

  def list
    noko.xpath('.//table[.//th[contains(
      translate(., "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"),
    "term of office")]]')
  end
end

class PartialDate
  def initialize(str)
    @str = str.tidy
  end

  def to_s
    # There must be a nicer way to do this
    shorttext.split('-').map { |num| num.rjust(2, "0") }.join('-')
  end

  private

  attr_reader :str

  def parts
    str.split(' ').reverse
  end

  def longtext
    parts.join('-')
  end

  def shorttext
    longtext.gsub(MONTHS_RE) { |name| MONTHS.find_index(name) }
  end

  MONTHS = %w(NULL January February March April May June July August September October November December)
  MONTHS_RE = Regexp.new(MONTHS.join('|'))
end


# Each officeholder in the list
class HolderItem < Scraped::HTML
  field :id do
    name_cell.css('a/@wikidata').map(&:text).first
  end

  field :name do
    name_cell.css('a/@title').map(&:text).map(&:tidy).first
  end

  field :start_date do
    PartialDate.new(start_text).to_s
  end

  field :end_date do
    return if end_text == 'Incumbent'

    PartialDate.new(end_text).to_s
  end

  field :replaces do
  end

  field :replaced_by do
  end

  def empty?
    name.to_s.empty?
  end

  private

  def tds
    noko.css('td,th')
  end

  def start_text
    start_date_cell.children.map(&:text).join(" ").tidy
  end

  def end_text
    end_date_cell.children.map(&:text).join(" ").tidy
  end

  def name_cell
    tds[2]
  end

  def start_date_cell
    tds[3]
  end

  def end_date_cell
    tds[4]
  end
end

url = ARGV.first || abort("Usage: #{$0} <url to scrape>")
data = Scraped::Scraper.new(url => ListPage).scraper.officeholders

data.each_cons(2) do |prev, cur|
  cur[:replaces] = prev[:id]
  prev[:replaced_by] = cur[:id]
end

header = data[1].keys.to_csv
rows = data.map { |row| row.values.to_csv }
puts header + rows.join
