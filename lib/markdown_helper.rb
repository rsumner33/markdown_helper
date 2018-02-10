require 'markdown_helper/version'

module MarkdownHelper

  class Options

    attr_accessor \
      :code_block,
      :tag_as_generated

    DEFAULT_CODE_BLOCK = {
        :md => nil,
        :rb => 'ruby',
        :xml => 'xml',
        }

    def initialize(code_block = DEFAULT_CODE_BLOCK, tag_as_generated: false)
      self.code_block = code_block.clone
      self.code_block.default = ''
      self.tag_as_generated = tag_as_generated
    end

  end

  FILE_SOURCE_TAG = '[include_file]'

  def self.include(template_file_path, markdown_file_path, options = Options.new)
    output_lines = []
    File.open(template_file_path, 'r') do |template_file|
      if options.tag_as_generated
        output_lines.push("<!--- GENERATED FILE, DO NOT EDIT --->\n")
      end
      template_file.each_line do |input_line|
        unless input_line.start_with?(FILE_SOURCE_TAG)
          output_lines.push(input_line)
          next
        end
        relative_path = input_line.sub(FILE_SOURCE_TAG, '').gsub(/[()]/, '').strip
        include_file_path = File.join(
            File.dirname(template_file_path),
            relative_path,
        )
        included_text = File.read(include_file_path)
        unless included_text.match("\n")
          message = "Warning:  Included file has no trailing newline: #{include_file_path}"
          warn(message)
        end
        extname = File.extname(include_file_path)
        code_block_key = extname.sub('.', '').to_sym
        highlight_language = options.code_block[code_block_key]
        if highlight_language.nil?
          # Pass through unadorned.
          output_lines.push(included_text)
        else
          # Treat as code block.
          # Label the block with its file name.
          file_name_line = format("<code>%s</code>\n", File.basename(include_file_path))
          output_lines.push(file_name_line)
          output_lines.push("```#{highlight_language}\n")
          output_lines.push(included_text)
          output_lines.push("```\n")
        end
      end
    end
    output = output_lines.join('')
    File.open(markdown_file_path, 'w') do |md_file|
      md_file.write(output)
    end
    output
  end

end