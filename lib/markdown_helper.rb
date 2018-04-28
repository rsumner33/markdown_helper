require 'pathname'
require 'markdown_helper/version'

# Helper class for working with GitHub markdown.
#  Supports file inclusion.
#
# @author Burdette Lamar
class MarkdownHelper

  IMAGE_REGEXP = /!\[([^\[]+)\]\(([^)]+)\)/
  INCLUDE_REGEXP = /^@\[([^\[]+)\]\(([^)]+)\)$/

  attr_accessor :pristine

  def initialize(options = {})
    default_options = {
        :pristine => false,
    }
    merged_options = default_options.merge(options)
    merged_options.each_pair do |method, value|
      unless self.respond_to?(method)
        raise ArgumentError.new("Unknown option: #{method}")
      end
      setter_method = "#{method}="
      send(setter_method, value)
      merged_options.delete(method)
    end
  end

  # Merges external files into markdown text.
  # @param template_file_path [String] the path to the input template markdown file, usually containing include pragmas.
  # @param markdown_file_path [String] the path to the output merged markdown file.
  # @return [String] the resulting markdown text.
  #
  # @example pragma to include text as a highlighted code block.
  #   @[ruby](foo.rb)
  #
  # @example pragma to include text as a plain code block.
  #   @[:code_block](foo.xyz)
  #
  # @example pragma to include text verbatim, to be rendered as markdown.
  #   @[:verbatim](foo.md)
  def include(template_file_path, markdown_file_path)
    send(:generate_file, template_file_path, markdown_file_path, __method__) do |input_lines, output_lines|
      send(:include_files, template_file_path, input_lines, output_lines, verbatim_inclusions = {})
    end
  end

  # Resolves relative image paths to absolute urls in markdown text.
  # @param template_file_path [String] the path to the input template markdown file, usually containing image pragmas.
  # @param markdown_file_path [String] the path to the output resolved markdown file.
  # @return [String] the resulting markdown text.
  #
  # This matters because when markdown becomes part of a Ruby gem,
  # its images will have been relocated in the documentation at RubyDoc.info, breaking the paths.
  # The resolved (absolute) urls, however, will still be valid.
  #
  # ENV['REPO_USER'] and ENV['REPO_NAME'] must give the user name and repository name of the relevant GitHub repository.
  #  must give the repo name of the relevant GitHub repository.
  #
  # @example pragma for an image:
  #   ![image_icon](images/image.png)
  #
  # The path resolves to:
  #
  #   absolute_file_path = File.join(
  #       "https://raw.githubusercontent.com/#{repo_user}/#{repo_name}/master",
  #       relative_file_path,
  #   )
  def resolve(template_file_path, markdown_file_path)
    # Method :generate_file does the first things, yields the block, does the last things.
    send(:generate_file, template_file_path, markdown_file_path, __method__) do |input_lines, output_lines|
      send(:resolve_images, input_lines, output_lines)
    end
  end
  alias resolve_image_urls resolve

  private

  def comment(text)
    "<!--#{text}-->\n"
  end

  def repo_user_and_name
    repo_user = ENV['REPO_USER']
    repo_name = ENV['REPO_NAME']
    unless repo_user and repo_name
      message = 'ENV values for both REPO_USER and REPO_NAME must be defined.'
      raise RuntimeError.new(message)
    end
    [repo_user, repo_name]
  end

  def generate_file(template_file_path, markdown_file_path, method)
    output_lines = []
    File.open(template_file_path, 'r') do |template_file|
      output_lines.push(comment(" >>>>>> BEGIN GENERATED FILE (#{method.to_s}): SOURCE #{template_file_path} ")) unless pristine
      input_lines = template_file.readlines
      yield input_lines, output_lines
      output_lines.push(comment(" <<<<<< END GENERATED FILE (#{method.to_s}): SOURCE #{template_file_path} ")) unless pristine
    end
    output = output_lines.join('')
    File.open(markdown_file_path, 'w') do |md_file|
      md_file.write(output)
    end
    output
  end

  def include_files(includer_file_path, input_lines, output_lines, verbatim_inclusions)

    input_lines.each_with_index do |input_line, line_index|
      match_data = input_line.match(INCLUDE_REGEXP)
      unless match_data
        output_lines.push(input_line)
        next
      end
      treatment = match_data[1]
      relative_included_file_path = match_data[2]
      treatment = case treatment
                    when ':code_block'
                      :code_block
                    when ':verbatim'
                      :verbatim
                    when ':comment'
                      :comment
                    else
                      treatment
                  end
      new_inclusion = Inclusion.new(
          includer_file_path,
          includer_line_number = line_index + 1,
          relative_included_file_path
      )
      included_real_path = new_inclusion.included_real_path
      if treatment == :verbatim
        previously_included = verbatim_inclusions.include?(new_inclusion.included_real_path)
        if previously_included
          backtrace = verbatim_inclusions.values.push(new_inclusion)
          message_lines = ['Includes are circular:']
          backtrace.each_with_index do |inclusion, i|
            message_lines.push("  Level #{i}:")
            message_lines.push("    Includer: #{inclusion.includer_file_path}:#{inclusion.includer_line_number}")
            message_lines.push("    Relative file path: #{inclusion.relative_included_file_path}")
            message_lines.push("    Included file path: #{inclusion.included_file_path}")
            message_lines.push("    Real file_path: #{inclusion.included_real_path}")
          end
          message = message_lines.join("\n")
          raise RuntimeError.new(message)
        end
        verbatim_inclusions[included_real_path] = new_inclusion
      end
      output_lines.push(comment(" >>>>>> BEGIN INCLUDED FILE (#{treatment}): SOURCE #{new_inclusion.included_file_path} ")) unless pristine
      include_lines = File.readlines(new_inclusion.included_file_path)
      unless include_lines.last.match("\n")
        message = "Warning:  Included file has no trailing newline: #{relative_included_file_path}"
        warn(message)
      end
      case treatment
        when :verbatim
          # Pass through unadorned, but honor any nested includes.
          include_files(new_inclusion.included_file_path, include_lines, output_lines, verbatim_inclusions)
        when :comment
          output_lines.push(comment(include_lines.join('')))
        else
          # Use the file name as a label.
          file_name_line = format("<code>%s</code>\n", File.basename(relative_included_file_path))
          output_lines.push(file_name_line)
          # Put into code block.
          language = treatment == :code_block ? '' : treatment
          output_lines.push("```#{language}\n")
          output_lines.push(*include_lines)
          output_lines.push("```\n")
      end
      output_lines.push(comment(" <<<<<< END INCLUDED FILE (#{treatment}): SOURCE #{new_inclusion.included_file_path} ")) unless pristine
    end
  end

  def resolve_images(input_lines, output_lines)
    input_lines.each do |input_line|
      scan_data = input_line.scan(IMAGE_REGEXP)
      if scan_data.empty?
        output_lines.push(input_line)
        next
      end
      output_lines.push(comment(" >>>>>> BEGIN RESOLVED IMAGES: INPUT-LINE '#{input_line}' ")) unless pristine
      output_line = input_line
      scan_data.each do |alt_text, path_and_attributes|
        relative_file_path, attributes_s =path_and_attributes.split(/\s?\|\s?/, 2)
        attributes = attributes_s ? attributes_s.split(/\s+/) : []
        formatted_attributes = ['']
        attributes.each do |attribute|
          name, value = attribute.split('=', 2)
          formatted_attributes.push(format('%s="%s"', name, value))
        end
        formatted_attributes_s = formatted_attributes.join(' ')
        repo_user, repo_name = repo_user_and_name
        if relative_file_path.start_with?('http')
          absolute_file_path = relative_file_path
        else
          absolute_file_path = File.join(
              "https://raw.githubusercontent.com/#{repo_user}/#{repo_name}/master",
              relative_file_path,
          )
        end
        img_element = format(
            '<img src="%s" alt="%s"%s>',
            absolute_file_path,
            alt_text,
            formatted_attributes_s,
        )
        output_line = output_line.sub(IMAGE_REGEXP, img_element)
      end
      output_lines.push(output_line)
      output_lines.push(comment(" <<<<<< END RESOLVED IMAGES: INPUT-LINE '#{input_line}' ")) unless pristine
    end

  end

  class Inclusion

    attr_accessor \
      :includer_file_path,
      :includer_line_number,
      :relative_included_file_path,
      :included_file_path,
      :included_real_path

    def initialize(
        includer_file_path,
        includer_line_number,
        relative_included_file_path
    )
      included_file_path = File.join(
          File.dirname(includer_file_path),
          relative_included_file_path,
      )
      self.includer_file_path = includer_file_path
      self.includer_line_number = includer_line_number
      self.relative_included_file_path = relative_included_file_path
      self.included_file_path = included_file_path
      self.included_real_path = Pathname.new(included_file_path).realpath.to_s
    end

  end

end

