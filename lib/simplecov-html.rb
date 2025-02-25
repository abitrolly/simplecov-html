# frozen_string_literal: true

require "erb"
require "cgi"
require "fileutils"
require "digest/sha1"
require "time"

# Ensure we are using a compatible version of SimpleCov
major, minor, patch = SimpleCov::VERSION.scan(/\d+/).first(3).map(&:to_i)
if major < 0 || minor < 9 || patch < 0
  raise "The version of SimpleCov you are using is too old. "\
  "Please update with `gem install simplecov` or `bundle update simplecov`"
end

module SimpleCov
  module Formatter
    class HTMLFormatter
      def initialize
        @branchable_result = SimpleCov.branch_coverage?
      end

      def format(result)
        Dir[File.join(File.dirname(__FILE__), "../public/*")].each do |path|
          FileUtils.cp_r(path, asset_output_path)
        end

        File.open(File.join(output_path, "index.html"), "wb") do |file|
          file.puts template("layout").result(binding)
        end
        puts output_message(result)
      end

      def output_message(result)
        "Coverage report generated for #{result.command_name} to #{output_path}. #{result.covered_lines} / #{result.total_lines} LOC (#{result.covered_percent.round(2)}%) covered."
      end

      def branchable_result?
        # cached in initialize because we truly look it up a whole bunch of times
        # and it's easier to cache here then in SimpleCov because there we might
        # still enable/disable branch coverage criterion
        @branchable_result
      end

      def line_status?(source_file, line)
        if branchable_result? && source_file.line_with_missed_branch?(line.number)
          "missed-branch"
        else
          line.status
        end
      end

    private

      # Returns the an erb instance for the template of given name
      def template(name)
        ERB.new(File.read(File.join(File.dirname(__FILE__), "../views/", "#{name}.erb")))
      end

      def output_path
        SimpleCov.coverage_path
      end

      def asset_output_path
        return @asset_output_path if defined?(@asset_output_path) && @asset_output_path

        @asset_output_path = File.join(output_path, "assets", SimpleCov::Formatter::HTMLFormatter::VERSION)
        FileUtils.mkdir_p(@asset_output_path)
        @asset_output_path
      end

      def assets_path(name)
        File.join("./assets", SimpleCov::Formatter::HTMLFormatter::VERSION, name)
      end

      # Returns the html for the given source_file
      def formatted_source_file(source_file)
        template("source_file").result(binding)
      rescue Encoding::CompatibilityError => e
        puts "Encoding problems with file #{source_file.filename}. Simplecov/ERB can't handle non ASCII characters in filenames. Error: #{e.message}."
      end

      # Returns a table containing the given source files
      def formatted_file_list(title, source_files)
        title_id = title.gsub(/^[^a-zA-Z]+/, "").gsub(/[^a-zA-Z0-9\-_]/, "")
        template("file_list").result(binding)
      end

      def covered_percent(percent)
        template("covered_percent").result(binding)
      end

      def coverage_css_class(covered_percent)
        if covered_percent > 90
          "green"
        elsif covered_percent > 80
          "yellow"
        else
          "red"
        end
      end

      def strength_css_class(covered_strength)
        if covered_strength > 1
          "green"
        elsif covered_strength == 1
          "yellow"
        else
          "red"
        end
      end

      # Return a (kind of) unique id for the source file given. Uses SHA1 on path for the id
      def id(source_file)
        Digest::SHA1.hexdigest(source_file.filename)
      end

      def timeago(time)
        "<abbr class=\"timeago\" title=\"#{time.iso8601}\">#{time.iso8601}</abbr>"
      end

      def shortened_filename(source_file)
        source_file.filename.sub(SimpleCov.root, ".").gsub(/^\.\//, "")
      end

      def link_to_source_file(source_file)
        %(<a href="##{id source_file}" class="src_link" title="#{shortened_filename source_file}">#{shortened_filename source_file}</a>)
      end
    end
  end
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))
require "simplecov-html/version"
