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

# Each officeholder in the list
class HolderItem < Scraped::HTML
  field :id do
    name_cell.css('a/@wikidata').map(&:text).first
  end

  field :name do
    name_cell.css('a/@title').map(&:text).map(&:tidy).first
  end

  field :start_date do
    Date.parse(start_text) if start_text[/\d+ \w+ \d{4}/]
  end

  field :end_date do
    return if end_text == 'Incumbent'

    Date.parse(end_text) if end_text[/\d+ \w+ \d{4}/]
  end

  field :replaces do
  end

  field :replaced_by do
  end

  def empty?
    name.to_s.empty? || (start_date.to_s.empty? && end_date.to_s.empty?)
  end

  private

  def tds
    noko.css('td,th')
  end

  def start_text
    start_date_cell.text.tidy
  end

  def end_text
    end_date_cell.text.tidy
  end

  def name_cell
    tds[1]
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
