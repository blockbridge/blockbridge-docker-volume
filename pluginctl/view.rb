# Copyright (c) 2015-2017, Blockbridge Networks LLC.  All rights reserved.
# Use of this source code is governed by a BSD-style license, found
# in the LICENSE file.

require 'active_support/inflector'
require 'csv'
require 'io/console'
require 'jsonpath'
require 'hashie'

require 'volume_driver/helpers/errors'
require 'volume_driver/helpers/cli'
require 'volume_driver/help'
require 'blockbridge/util/tabular'

module Blockbridge
  module Results
    def render(data, opts = {})
      if raw?
        if opts[:cmd] && opts[:cmd].yaml?
          data.to_yaml
        else
          JSON.pretty_generate(data)
        end
      else
        begin
          script = respond_to?(:process) && process
          if script
            Blockbridge::View.new.render_script(script, data, opts)
          else
            # try to automatically determine a template name
            name = [opts[:view],
                    class_name_template,
                    invocation_path_template].compact
            Blockbridge::View.new.render(name, data, opts)
          end
        rescue RuntimeError
          raise
        rescue => e
          raise e if debug?

          s = "failed to render template #{name}: #{e.message}"
          s << "\n\nException backtrace:\n"
          s << e.backtrace.join("\n")

          if debug?
            s << "\n\nRaw JSON follows:\n\n"
          end
          if debug?
            s << JSON.pretty_generate(data)
          end
        end
      end
    end

    def invocation_path_template
      @invocation_path.sub(/^bb[^ ]* /, '').gsub(/[ -]/, '_')
    end

    def class_name_template
      return if self.class == Class
      "#{@invocation_path.split(' ').first}_#{self.class.name.underscore}"
    end
  end

  class View
    include Helpers::Cli

    def initialize(opts = {})
      @@view_data ||= {}
      @opts = opts
      @cur_opts = nil
      @cur_data = nil
      @ref_cache = {}
    end

    def render(name, data, opts = {})
      @debug = opts[:cmd] && opts[:cmd].debug?
      view_exec, view_file = view_data_for(name)
      render_(name, view_exec, view_file, data, opts)
    end

    def render_script(script, data, opts = {})
      @debug = opts[:cmd] && opts[:cmd].debug?
      render_("<script>", script, nil, data, opts)
    end

    private

    # proxy to supplied opts hash
    def options
      @cur_opts
    end

    def cmd
      @cur_cmd
    end

    def data
      @cur_data
    end

    def terminal_size
      @terminal_size ||= IO.console.nil? ? [24, 80] : IO.console.winsize
    end

    def terminal_cols
      terminal_size[1]
    end

    def terminal_rows
      terminal_size[0]
    end

    def data_file_path(name)
      File.join(File.dirname(__FILE__), 'views', "#{name}.rb")
    end

    def view_data_for(name)
      if name.respond_to? :each
        file = name.map { |n| data_file_path(n) }.find { |p| File.exists? p }
      else
        file = data_file_path(name)
      end

      return @@view_data[file] if @@view_data.key? file

      dat = nil

      begin
        File.open(file) do |f|
          dat = f.read
        end
      rescue
        dat = nil
      end
      @@view_data[file] = [dat, file]

      [dat, file]
    end

    def template_exists?(name)
      view_exec, view_file = view_data_for name
      !view_exec.nil?
    end

    def render_(name, view_exec, view_file, data, opts = {})
      begin
        output = nil

        @term_width = opts[:width] || terminal_cols

        # set current options and wrap with a Mash for easy access.
        _opts = @cur_opts
        _data = @cur_data
        _cmd  = @cur_cmd
        _out  = @cur_out

        @cur_opts = Hashie::Mash.new(opts).merge(@opts)
        @cur_data = data
        @cur_cmd  = opts[:cmd]
        @cur_out  = StringIO.new

        if view_exec.nil?
          #if opts[:partial]
          #  Kernel.puts "# no partial for '#{name}', rendering raw data:"
          #else
          #  Kernel.puts "# no template for '#{name}', rendering raw data:"
          #end
          @cur_out << JSON.pretty_generate(data)
        else
          if view_file.nil?
            lambda { instance_eval(view_exec) }.call
          else
            lambda { instance_eval(view_exec, view_file) }.call
          end
        end

        output = @cur_out.string

      rescue SyntaxError, StandardError => e
        if @debug
          Kernel.puts "Backtrace for render exception #{e.inspect}:"
          Kernel.puts e.backtrace
          Kernel.puts

          raise "Failed to render view for #{name}: #{e.message}"
        else
          raise "Failed to render view for #{name}: #{e.message}"
        end

      ensure
        @cur_opts = _opts
        @cur_data = _data
        @cur_cmd  = _cmd
        @cur_out  = _out
      end

      output
    end

    ##################################################
    # higher-level helpers
    ##################################################

    def header(title, color = nil)
      if color
        raw color("== #{title}\n", *color)
      else
        raw "== #{title}\n"
      end
    end

    def vspace(lines = 1)
      raw "\n" * lines
    end

    def color(s, *c)
      Paint[s, *c]
    end

    def field_options(opts = {}, &block)
      return unless block_given?

      cur_options = @field_options

      begin
        @field_options = opts
        yield @field_options
      ensure
        @field_options = cur_options
      end
    end

    def fieldset(title, opts = {})
      raise TemplateError.new("fieldset requires a block") unless block_given?

      return if opts[:verbose] && !options.verbose
      return if opts.key?(:data) && opts[:data].nil?

      padding = opts[:padding] || 1

      # headings get colored
      if opts[:heading] && !opts[:header_color]
        opts[:header_color] = [:cyan]
      end

      tabular_opts = {
        header: false,
        max_width: terminal_cols - 1,
        cols: [ { label: 'key', min: 20, max: 25 }, { label: 'value' } ]
      }

      @fieldset = Blockbridge::Util::Tabular.new(tabular_opts)
      begin
        yield @fieldset, opts[:data]
        unless @fieldset.hide
          header title, opts[:header_color] unless title.nil?
          raw @fieldset.render
          raw "\n" * padding
        end
      rescue NoMethodError => e
        raise unless e.message.include?("nil:NilClass") && !@debug

        header title, opts[:header_color]
        raw opts.fetch(:exception_message, " -data unavailable-")
        raw "\n\n" * padding

      ensure
        @fieldset = nil
      end
    end

    def field(name, val = nil, opts = {}, &block)
      raise TemplateError.new("field must be inside a fieldset") if @fieldset.nil?

      if @field_options
        opts = @field_options.merge(opts)
      end

      return if opts[:verbose] && !options.verbose

      begin
        val = val.call if val.respond_to?(:call)
      rescue NoMethodError => e
        raise unless e.message.include?("nil:NilClass") && !@debug
        val = nil
      end

      begin
        val = format_value(val, opts, &block)
      rescue NoMethodError => e
        raise unless e.message.include?("nil:NilClass") && !@debug
      end

      return if val.nil?

      @fieldset << [ Paint[name, :bold], val.to_s ]
    end

    def fields_from_hash(h, &blk)
      return if h.nil?

      h.each_pair do |k, v|
        field k.to_s.tr('_', ' '), v
      end
    end

    def hide_if_empty
      raise TemplateError.new("hide_if_empty must be inside a fieldset") if @fieldset.nil?

      @fieldset.hide = @fieldset.rows.length == 0
    end

    def raw(*args)
      args.each { |a| @cur_out << a }
    end

    def print(*args)
      @cur_out.print(*args)
    end

    def puts(*args)
      @cur_out.puts(*args)
    end

    def output
      @cur_out
    end

    def empty_table(str = " -none-")
      raw str + "\n\n"
    end

    def table(opts = {})
      raise TemplateError.new("table requires a block") unless block_given?

      padding = opts[:padding] || 1

      # sort by first col by default, but allow the view to override the
      # default.
      dfl_sort = 0
      if opts.has_key? :sort_cols
        dfl_sort = opts.delete :sort_cols
      end

      tabular_opts = {
        sort_cols: @cur_opts.fetch(:sort_cols, dfl_sort), # allow cli arg override, too.
        header: true,
        max_width: terminal_cols - 1,
      }.merge(opts)

      @table = Blockbridge::Util::Tabular.new(tabular_opts)
      begin
        yield @table
        raw @table.render
        raw "\n" * padding
      ensure
        @table = nil
      end
    end

    def partial(name, data, opts = {})
      # partials start with an underscore (borrowed this idea from Middleman.)
      name = "_#{name.to_s}"

      # merge current options with new options; this preserves command and
      # option context. set partial flag to avoid suppressing/capturing
      # output.
      opts = @cur_opts.merge(opts)
      opts[:partial] = true

      # return the value, in case some upper-template is actually rendering
      # the value into the output stream. (e.g., using partials for rendering
      # simple things like object status.)
      render(name, data, opts)
    end

    def partial_out(name, data, opts = {})
      raw partial(name, data, opts)
    end

    def render_out(name, data, opts = nil)
      raw render(name, data, opts || @cur_opts)
    end
  end
end
